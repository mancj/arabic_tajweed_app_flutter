// Регрессия: отпускание кнопки во время запроса доступа к микрофону должно
// остановить запись после её запуска, иначе микрофон останется включённым.
import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/data/pronunciation_checker.dart';
import 'package:arabic_tajweed_app/data/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('остановка ждёт завершения запуска микрофона', () async {
    final recorder = _DelayedRecorder();
    final checker = PronunciationChecker(recorder: recorder);
    addTearDown(checker.dispose);

    final starting = checker.start();
    final stopping = checker.stop(expected: 'ا');
    expect(recorder.stopCount, 0);

    recorder.ready.complete(true);
    await starting;
    await stopping;

    expect(recorder.stopCount, 1);
    expect(checker.isRecording.value, isFalse);
    expect(checker.error.value, 'Запись не удалась');
  });
}

class _DelayedRecorder extends VoiceRecorder {
  final Completer<bool> ready = Completer<bool>();
  int stopCount = 0;

  @override
  Future<bool> start() => ready.future;

  @override
  Future<File?> stop() async {
    stopCount++;
    return null;
  }
}
