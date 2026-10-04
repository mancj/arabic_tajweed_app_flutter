import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import 'rest/api_exception.dart';
import 'rest/letter_check.dart';
import 'rest/pronunciation_rest_client.dart';
import 'rest/syllable_check.dart';
import 'pronunciation_preference.dart';
import 'microphone_permission.dart';
import 'voice_recorder.dart';

/// Одна цепочка «записал — отправил — ответ сервера». Экран урока
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
  Future<void>? _starting;
  Future<void>? _cancellingRecording;
  CancelToken _cancelToken = CancelToken();
  int _generation = 0;
  bool _disposed = false;

  ValueListenable<double> get level => _recorder.level;

  /// Микрофон пишет после нажатия или во время удержания кнопки.
  final isRecording = false.obs;

  /// Запись ушла на сервер, ждём вердикт.
  final isChecking = false.obs;

  /// Что сервер услышал в последней записи. Null — записи ещё не было.
  final result = Rxn<LetterCheck>();

  final syllableResult = Rxn<SyllableCheck>();

  /// Записать или проверить не удалось: текст для экрана.
  final error = RxnString();

  /// Техническая причина пропуска. Ответ сервера с несовпавшей буквой —
  /// обычная учебная ошибка и здесь никогда не появляется.
  final failure = Rxn<PronunciationFailureKind>();

  /// После окончательного отказа разрешение меняется в настройках устройства.
  final microphoneSettingsRequired = false.obs;

  /// Начать запись сразу после нажатия. Повторное нажатие во время запуска
  /// не создаёт вторую запись.
  Future<void> start() async {
    final generation = _generation;
    if (_cancellingRecording case final cancelling?) await cancelling;
    if (generation != _generation) return;
    if (_disposed) return;
    if (_starting case final starting?) {
      await starting;
      return;
    }
    if (isRecording.value || isChecking.value) return;
    final starting = _startRecorder(generation);
    _starting = starting;
    try {
      await starting;
    } finally {
      if (identical(_starting, starting)) _starting = null;
    }
  }

  Future<void> _startRecorder(int generation) async {
    error.value = null;
    failure.value = null;
    microphoneSettingsRequired.value = false;
    try {
      final started = await _recorder.start();
      if (_disposed) return;
      if (generation != _generation) {
        if (started) await _cancelRecording();
        return;
      }
      if (!started) {
        error.value = 'Нет доступа к микрофону';
        failure.value = PronunciationFailureKind.microphoneDenied;
        microphoneSettingsRequired.value =
            _recorder.lastPermissionResult ==
            MicrophonePermissionResult.settingsRequired;
        return;
      }
      isRecording.value = true;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error.value = 'Запись не удалась';
      failure.value = PronunciationFailureKind.recordingFailed;
    }
  }

  /// Остановить запись и спросить сервер, названа ли
  /// буква [expected] (сам глиф). Null — записи не вышло или сервер
  /// не ответил; причина уже в [error].
  Future<LetterCheck?> stop({required String expected}) => _stop(
    (client, file, cancelToken) => client.checkLetter(
      audio: file,
      expected: expected,
      cancelToken: cancelToken,
    ),
    (check) => result.value = check,
  );

  Future<SyllableCheck?> stopSyllable({required String expected}) => _stop(
    (client, file, cancelToken) => client.checkSyllable(
      audio: file,
      expected: expected,
      cancelToken: cancelToken,
    ),
    (check) => syllableResult.value = check,
    checkingSyllable: true,
  );

  Future<T?> _stop<T>(
    Future<T> Function(PronunciationRestClient, File, CancelToken) send,
    void Function(T) save, {
    bool checkingSyllable = false,
  }) async {
    final generation = _generation;
    final cancelToken = _cancelToken;
    if (_starting case final starting?) await starting;
    if (_disposed || generation != _generation || !isRecording.value) {
      return null;
    }
    isRecording.value = false;
    isChecking.value = true;

    final file = await _recorder.stop().catchError((_) => null);
    if (_disposed || generation != _generation) {
      if (file != null) {
        unawaited(file.delete().then((_) {}, onError: (_) {}));
      }
      return null;
    }
    if (file == null) {
      isChecking.value = false;
      error.value = 'Запись не удалась';
      failure.value = PronunciationFailureKind.recordingFailed;
      return null;
    }

    try {
      if (kDebugMode) await 200.ms.delay();
      if (_disposed || generation != _generation) return null;
      _client ??= Get.find<PronunciationRestClient>();
      final check = await send(_client!, file, cancelToken);
      if (_disposed || generation != _generation) return null;
      save(check);
      failure.value = null;
      return check;
    } on ApiException catch (e) {
      if (_disposed ||
          generation != _generation ||
          e is RequestCancelledException) {
        return null;
      }
      error.value = switch (e) {
        NoConnectionException() => 'Сервер проверки недоступен',
        NotFoundException() when checkingSyllable =>
          'Проверка слогов пока недоступна на сервере',
        _ => 'Проверка не удалась: ${e.message}',
      };
      failure.value = PronunciationFailureKind.serviceUnavailable;
      return null;
    } catch (_) {
      if (_disposed || generation != _generation) return null;
      error.value = 'Не удалось прочитать ответ сервера';
      failure.value = PronunciationFailureKind.serviceUnavailable;
      return null;
    } finally {
      if (!_disposed && generation == _generation) isChecking.value = false;
      unawaited(file.delete().then((_) {}, onError: (_) {}));
    }
  }

  /// Пропуск или новое задание отменяет и запись, и её проверку. Поздний
  /// ответ или системное разрешение уже не относятся к текущему заданию.
  void reset() {
    if (_disposed) return;
    _generation++;
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    if (isRecording.value) {
      _cancellingRecording = _cancelRecording();
    }
    isRecording.value = false;
    isChecking.value = false;
    result.value = null;
    syllableResult.value = null;
    error.value = null;
    failure.value = null;
    microphoneSettingsRequired.value = false;
  }

  Future<void> _cancelRecording() async {
    final file = await _recorder.stop().catchError((_) => null);
    if (file != null) {
      await file.delete().then((_) {}, onError: (_) {});
    }
  }

  Future<bool> openMicrophoneSettings() => _recorder.openSettings();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelToken.cancel();
    // Запуск микрофона может ещё ждать системного разрешения.
    final starting = _starting;
    if (starting != null) {
      unawaited(starting.whenComplete(_recorder.dispose));
    } else {
      _recorder.dispose();
    }
  }
}
