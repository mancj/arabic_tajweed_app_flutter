import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';

/// Короткая запись голоса с микрофона: одна за раз, во временный файл.
///
/// Пишем AAC в m4a на обеих платформах: сервер его принимает, а wav
/// на Android системный рекордер не умеет. Частота и битрейт — как у
/// системы по умолчанию: кодировщик Apple не принимает 16 кГц с битрейтом
/// 64 кбит/с, запись стартует, а файл выходит пустым внутри. Сервер сам
/// приводит звук к нужной частоте.
///
/// Рекордер создаётся при первой записи, а не вместе с экраном: у него
/// платформенный канал, которого в тестах нет.
class VoiceRecorder {
  RecorderController? _controller;

  RecorderController get _recorder => _controller ??= RecorderController()
    ..androidEncoder = AndroidEncoder.aac
    ..androidOutputFormat = AndroidOutputFormat.mpeg4
    ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
    ..sampleRate = 44100;

  /// Начать запись. Ложь — нет доступа к микрофону.
  Future<bool> start() async {
    if (!await _recorder.checkPermission()) return false;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await _recorder.record(path: '${dir.path}/voice_$stamp.m4a');
    return true;
  }

  /// Остановить и отдать файл. Null — записи не было или она не сохранилась.
  /// Файл короче заголовка контейнера считаем несохранившимся: рекордер
  /// об отказе кодировщика не сообщает, а слать пустышку на сервер незачем.
  Future<File?> stop() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() < _minFileBytes) {
      return null;
    }
    return file;
  }

  static const _minFileBytes = 1024;

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
