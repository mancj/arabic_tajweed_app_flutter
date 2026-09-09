import 'dart:async';
import 'dart:io';

// PlayerState прячем: одноимённый класс есть и в audioplayers, а нужен
// здесь именно его — состояние настоящего плеера.
import 'package:audio_waveforms/audio_waveforms.dart' hide PlayerState;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/audio_track.dart';

/// Звучание букв: запись имени буквы, одна на все её формы.
///
/// Файл ищется по `letterId`, а не задаётся в контенте: ب в начале и в конце
/// звучит одинаково, и класть одно и то же имя файла в четыре атома незачем.
class LetterAudio {
  LetterAudio({AudioPlayer? player}) : _player = player;

  /// Плеер создаётся при первом воспроизведении, а не вместе с экраном:
  /// платформенный канал есть не везде — в тестах его нет вовсе, и создание
  /// в конструкторе роняло бы любой экран с буквой.
  AudioPlayer? _player;

  /// Что сейчас звучит: форма записи и позиция. На это подписана волна.
  final track = ValueNotifier<AudioTrack>(AudioTrack.silent);

  /// Пики уже разобранных записей: разбор файла стоит дорого, а буквы
  /// слушают по многу раз подряд.
  final _levels = <String, List<double>>{};
  final _subscriptions = <StreamSubscription<void>>[];

  /// Сколько столбиков снимаем с записи. Имя буквы — меньше секунды,
  /// шестидесяти точек хватает на узнаваемый силуэт.
  static const _sampleCount = 60;

  /// Буквы, для которых записан звук. Хамза и слоги пока без озвучки.
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
  Future<void> toggle(String? letterId) async {
    if (!has(letterId)) return;
    final player = _player;
    // Спрашиваем сам плеер, а не прогресс: после конца записи он шлёт
    // позицию 0, и по прогрессу доигравшая запись неотличима от начала.
    if (letterId == _current && player?.state == PlayerState.playing) {
      return stop();
    }
    return play(letterId);
  }

  /// Обрывает звук и возвращает волну в покой: продолжать с места нечего,
  /// следующее нажатие начнёт запись сначала.
  Future<void> stop() async {
    _current = null;
    track.value = AudioTrack.silent;
    try {
      await _player?.stop();
    } catch (_) {
      // Плеера может уже не быть — молчание и так наступило.
    }
  }

  /// Проигрывает имя буквы. Повторное нажатие обрывает предыдущий звук,
  /// а не накладывается на него.
  Future<void> play(String? letterId) async {
    if (!has(letterId)) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      _listen(player);
      _current = letterId;
      track.value = AudioTrack(
        levels: _levels[letterId] ?? const [],
        isPlaying: true,
      );
      // Форма снимается параллельно со звуком: первый раз она приезжает
      // с задержкой в пару кадров, и ждать её — значит задержать сам звук.
      unawaited(_loadLevels(letterId!));
      await player.play(AssetSource(assetOf(letterId)));
    } catch (_) {
      // Звук — не то, ради чего стоит ронять урок: если плеера нет,
      // молча продолжаем без него.
      _current = null;
      track.value = AudioTrack.silent;
    }
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
  Future<void> _loadLevels(String letterId) async {
    if (_levels.containsKey(letterId)) return;

    final controller = PlayerController();
    try {
      final file = await _fileOf(letterId);
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

      _levels[letterId] = levels;
      if (track.value.isPlaying) {
        track.value = track.value.copyWith(levels: levels);
      }
    } catch (_) {
      // Пустой список — знак «формы нет», и он тоже кэшируется: незачем
      // ходить в отсутствующий плагин на каждое нажатие.
      _levels[letterId] = const [];
    } finally {
      controller.dispose();
    }
  }

  /// Нативному разбору нужен файл на диске, ассет он открыть не может.
  Future<File> _fileOf(String letterId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/letter_$letterId.wav');
    if (!file.existsSync()) {
      final bytes = await rootBundle.load('assets/${assetOf(letterId)}');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    return file;
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    track.dispose();
    await _player?.dispose();
  }
}
