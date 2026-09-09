import 'dart:async';

import 'package:get/get.dart';

import 'rest/api_exception.dart';
import 'rest/letter_check.dart';
import 'rest/pronunciation_rest_client.dart';
import 'voice_recorder.dart';

/// Одна цепочка «нажал — сказал — отпустил — ответ сервера». Экран урока
/// и экран тренировки делят её целиком и различаются только тем, что
/// делают с ответом.
///
/// Клиент берётся из Get при первой записи, а не в конструкторе:
/// в тестах его нет.
class PronunciationChecker {
  PronunciationChecker({
    VoiceRecorder? recorder,
    PronunciationRestClient? client,
  }) : _recorder = recorder ?? VoiceRecorder(),
       _client = client;

  final VoiceRecorder _recorder;
  PronunciationRestClient? _client;

  /// Кнопка удерживается, микрофон пишет.
  final isRecording = false.obs;

  /// Запись ушла на сервер, ждём вердикт.
  final isChecking = false.obs;

  /// Что сервер услышал в последней записи. Null — записи ещё не было.
  final result = Rxn<LetterCheck>();

  /// Записать или проверить не удалось: текст для экрана.
  final error = RxnString();

  /// Палец лёг на кнопку: начать запись.
  Future<void> start() async {
    if (isRecording.value || isChecking.value) return;
    error.value = null;
    try {
      if (!await _recorder.start()) {
        error.value = 'Нет доступа к микрофону';
        return;
      }
      isRecording.value = true;
    } catch (_) {
      error.value = 'Запись не удалась';
    }
  }

  /// Палец поднят: остановить запись и спросить сервер, названа ли
  /// буква [expected] (сам глиф). Null — записи не вышло или сервер
  /// не ответил; причина уже в [error].
  Future<LetterCheck?> stop({required String expected}) async {
    if (!isRecording.value) return null;
    isRecording.value = false;

    final file = await _recorder.stop().catchError((_) => null);
    if (file == null) {
      error.value = 'Запись не удалась';
      return null;
    }

    isChecking.value = true;
    try {
      _client ??= Get.find<PronunciationRestClient>();
      final check = await _client!.checkLetter(audio: file, expected: expected);
      result.value = check;
      return check;
    } on ApiException catch (e) {
      error.value = switch (e) {
        NoConnectionException() => 'Сервер проверки недоступен',
        _ => 'Проверка не удалась: ${e.message}',
      };
      return null;
    } finally {
      isChecking.value = false;
      unawaited(file.delete().then((_) {}, onError: (_) {}));
    }
  }

  /// Новая буква или новое задание — прошлый ответ к делу не относится.
  void reset() {
    result.value = null;
    error.value = null;
  }

  void dispose() => _recorder.dispose();
}
