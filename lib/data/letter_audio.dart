import 'dart:async';
import 'dart:convert';
import 'dart:io';

// PlayerState прячем: одноимённый класс есть и в audioplayers, а нужен
// здесь именно его — состояние настоящего плеера.
import 'package:audio_waveforms/audio_waveforms.dart' hide PlayerState;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/audio_track.dart';
import 'lesson_audio.dart';

/// Звучание букв: запись имени буквы, одна на все её формы.
///
/// Файл ищется по `letterId`, а не задаётся в контенте: ب в начале и в конце
/// звучит одинаково, и класть одно и то же имя файла в четыре атома незачем.
class LetterAudio implements LessonAudio {
  LetterAudio({AudioPlayer? player}) : _player = player;

  /// Плеер создаётся при первом воспроизведении, а не вместе с экраном:
  /// платформенный канал есть не везде — в тестах его нет вовсе, и создание
  /// в конструкторе роняло бы любой экран с буквой.
  AudioPlayer? _player;
  FlutterTts? _tts;
  Timer? _ttsProgressTimer;
  String? _arabicLocale;

  /// Что сейчас звучит: форма записи и позиция. На это подписана волна.
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier<AudioTrack>(
    AudioTrack.silent,
  );

  /// Пики уже разобранных записей: разбор файла стоит дорого, а буквы
  /// слушают по многу раз подряд.
  final _levels = <String, List<double>>{};
  final _subscriptions = <StreamSubscription<void>>[];

  /// Сколько столбиков снимаем с записи. Имя буквы — меньше секунды,
  /// шестидесяти точек хватает на узнаваемый силуэт.
  static const _sampleCount = 60;

  /// Буквы, для которых записано имя. Записи слогов и слов задаются
  /// контентом через audioAsset; TTS используется для ещё не озвученного.
  static const letters = {
    'alif',
    'ba',
    'ta',
    'tha',
    'jim',
    'hha',
    'kha',
    'dal',
    'dhal',
    'ra',
    'zay',
    'sin',
    'shin',
    'sod',
    'dod',
    'to',
    'zho',
    'ayn',
    'ghayn',
    'fa',
    'qof',
    'kaf',
    'lam',
    'mim',
    'nun',
    'ha',
    'waw',
    'ya',
  };

  static bool has(String? letterId) => letters.contains(letterId);

  /// Путь внутри ассетов. AudioPlayer ждёт путь без префикса `assets/`.
  static String assetOf(String letterId) => 'audio/alphabet/$letterId.wav';

  /// Что стоит в плеере сейчас: нужно, чтобы отличить повторное нажатие
  /// по той же букве — это пауза — от перехода к другой букве.
  String? _current;

  /// Нажатие на кнопку: та же буква на ходу — остановка, любая другая
  /// (или уже смолкшая) — воспроизведение с начала.
  Future<void> toggle(String? letterId) =>
      toggleAsset(has(letterId) ? assetOf(letterId!) : null);

  @override
  Future<void> toggleAsset(String? asset) async {
    if (asset == null) return;
    if (asset == _current && track.value.isPlaying) {
      return stop();
    }
    return playAsset(asset);
  }

  /// Обрывает звук и возвращает волну в покой: продолжать с места нечего,
  /// следующее нажатие начнёт запись сначала.
  @override
  Future<void> stop() async {
    _ttsProgressTimer?.cancel();
    _ttsProgressTimer = null;
    _current = null;
    track.value = AudioTrack.silent;
    try {
      await _player?.stop();
      await _tts?.stop();
    } catch (_) {
      // Плеера может уже не быть — молчание и так наступило.
    }
  }

  /// Проигрывает имя буквы. Повторное нажатие обрывает предыдущий звук,
  /// а не накладывается на него.
  Future<void> play(String? letterId) =>
      playAsset(has(letterId) ? assetOf(letterId!) : null);

  @override
  Future<void> playAsset(String? asset) async {
    if (asset == null) return;
    if (asset.startsWith('tts:')) {
      await _speak(asset);
      return;
    }
    try {
      _ttsProgressTimer?.cancel();
      _ttsProgressTimer = null;
      await _tts?.stop();
      final player = _player ??= AudioPlayer();
      await player.stop();
      _listen(player);
      _current = asset;
      track.value = AudioTrack(
        levels: _levels[asset] ?? const [],
        isPlaying: true,
      );
      // Форма снимается параллельно со звуком: первый раз она приезжает
      // с задержкой в пару кадров, и ждать её — значит задержать сам звук.
      unawaited(_loadLevels(asset));
      await player.play(AssetSource(asset));
    } catch (_) {
      // Звук — не то, ради чего стоит ронять урок: если плеера нет,
      // молча продолжаем без него.
      _current = null;
      track.value = AudioTrack.silent;
    }
  }

  Future<void> _speak(String asset) async {
    try {
      await _player?.stop();
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      _arabicLocale ??= await _findArabicLocale(tts);
      if (_arabicLocale == null) {
        throw StateError('На устройстве нет арабского голоса');
      }
      await tts.setLanguage(_arabicLocale!);
      await tts.setSpeechRate(0.42);
      _current = asset;
      track.value = const AudioTrack(isPlaying: true);
      _startTtsProgress(asset);
      tts.setCompletionHandler(() {
        if (_current == asset) {
          _ttsProgressTimer?.cancel();
          _ttsProgressTimer = null;
          track.value = track.value.copyWith(progress: 1, isPlaying: false);
        }
      });
      tts.setErrorHandler((_) {
        if (_current == asset) {
          _ttsProgressTimer?.cancel();
          _ttsProgressTimer = null;
          track.value = AudioTrack.silent;
        }
      });
      await tts.speak(asset.substring(4));
    } catch (_) {
      _ttsProgressTimer?.cancel();
      _ttsProgressTimer = null;
      _current = null;
      track.value = AudioTrack.silent;
    }
  }

  /// TTS не сообщает позицию внутри фразы. Даём интерфейсу плавную оценку,
  /// а точный конец всё равно приходит из completion handler движка.
  void _startTtsProgress(String asset) {
    final symbols = asset.substring(4).runes.length;
    final estimate = Duration(milliseconds: 700 + symbols * 110);
    final watch = Stopwatch()..start();
    _ttsProgressTimer?.cancel();
    _ttsProgressTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (_current != asset || !track.value.isPlaying) {
        _ttsProgressTimer?.cancel();
        _ttsProgressTimer = null;
        return;
      }
      final progress = (watch.elapsedMilliseconds / estimate.inMilliseconds)
          .clamp(0, .94)
          .toDouble();
      track.value = track.value.copyWith(progress: progress);
    });
  }

  Future<String?> _findArabicLocale(FlutterTts tts) async {
    for (final locale in const ['ar-SA', 'ar-001', 'ar']) {
      final available = await tts.isLanguageAvailable(locale);
      if (available == true || available == 1) return locale;
    }
    return null;
  }

  /// Подписки вешаются один раз на плеер, а не на каждое нажатие.
  void _listen(AudioPlayer player) {
    if (_subscriptions.isNotEmpty) return;

    Duration total = Duration.zero;

    _subscriptions.addAll([
      player.onDurationChanged.listen((d) => total = d),
      player.onPositionChanged.listen((position) {
        if (total.inMilliseconds <= 0) return;
        track.value = track.value.copyWith(
          progress: (position.inMilliseconds / total.inMilliseconds).clamp(
            0.0,
            1.0,
          ),
        );
      }),
      player.onPlayerComplete.listen(
        (_) =>
            track.value = track.value.copyWith(progress: 1, isPlaying: false),
      ),
    ]);
  }

  /// Снимает форму записи. Извлечение живёт в нативной части пакета, то есть
  /// только на Android и iOS; на вебе и десктопе оно просто не отвечает —
  /// волна остаётся декоративной, и это нормально.
  Future<void> _loadLevels(String asset) async {
    if (_levels.containsKey(asset)) return;

    final controller = PlayerController();
    try {
      final file = await _fileOf(asset);
      final raw = await controller.extractWaveformData(
        path: file.path,
        noOfSamples: _sampleCount,
      );
      final peak = raw.isEmpty ? 0.0 : raw.reduce((a, b) => a > b ? a : b);
      // Записи сведены на разной громкости; без нормировки одна буква
      // рисуется во всю высоту, а соседняя — плоской ниточкой.
      final levels = peak <= 0
          ? const <double>[]
          : raw.map((v) => (v / peak).clamp(0.0, 1.0)).toList();

      _levels[asset] = levels;
      if (_current == asset && track.value.isPlaying) {
        track.value = track.value.copyWith(levels: levels);
      }
    } catch (_) {
      // Пустой список — знак «формы нет», и он тоже кэшируется: незачем
      // ходить в отсутствующий плагин на каждое нажатие.
      _levels[asset] = const [];
    } finally {
      controller.dispose();
    }
  }

  /// Нативному разбору нужен файл на диске, ассет он открыть не может.
  Future<File> _fileOf(String asset) async {
    final dir = await getTemporaryDirectory();
    final key = base64Url.encode(utf8.encode(asset)).replaceAll('=', '');
    final extension = asset.split('.').last;
    final file = File('${dir.path}/lesson_$key.$extension');
    if (!file.existsSync()) {
      final bytes = await rootBundle.load('assets/$asset');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    return file;
  }

  @override
  Future<void> dispose() async {
    _ttsProgressTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    track.dispose();
    await _player?.dispose();
    await _tts?.stop();
  }
}
