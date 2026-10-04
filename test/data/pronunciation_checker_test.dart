// Регрессия: остановка должна дождаться запуска микрофона, а постоянный отказ
// должен открыть путь в настройки, иначе голосовое задание остаётся тупиком.
// Выход без произношения и закрытие экрана прерывают HTTP-проверку, запись
// и подготовку файла; позднее разрешение не оставляет микрофон включённым.
// Неполный ответ /syllable и отсутствие метода остаются ошибками сервиса.
import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/data/pronunciation_checker.dart';
import 'package:arabic_tajweed_app/data/microphone_permission.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_rest_client.dart';

void main() {
  for (final syllable in [false, true]) {
    for (final reset in [false, true]) {
      test(
        '${reset ? 'пропуск' : 'закрытие'} прерывает запрос ${syllable ? 'слога' : 'буквы'} без ошибки и результата',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'checker_test',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = await File(
            '${directory.path}/voice.m4a',
          ).writeAsBytes([1]);
          final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
          addTearDown(() => dio.close(force: true));
          final sent = Completer<CancelToken>();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                sent.complete(options.cancelToken!);
              },
            ),
          );
          final recorder = _FileRecorder(Future.value(file));
          final checker = PronunciationChecker(
            recorder: recorder,
            client: PronunciationRestClient(dio: dio),
          );
          addTearDown(checker.dispose);
          await checker.start();
          final checking = syllable
              ? checker.stopSyllable(expected: 'بِ')
              : checker.stop(expected: 'ا');
          final token = await sent.future;
          if (reset) {
            checker.reset();
          } else {
            checker.dispose();
          }
          expect(token.isCancelled, isTrue);
          expect(await checking, isNull);
          expect(checker.error.value, isNull);
          expect(checker.failure.value, isNull);
          expect(checker.result.value, isNull);
          expect(checker.syllableResult.value, isNull);
        },
      );
    }
  }

  for (final reset in [false, true]) {
    test(
      '${reset ? 'пропуск' : 'закрытие'} во время подготовки файла не отправляет запрос',
      () async {
        final directory = await Directory.systemTemp.createTemp('checker_test');
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/voice.m4a',
        ).writeAsBytes([1]);
        final ready = Completer<File?>();
        final dio = Dio();
        addTearDown(() => dio.close(force: true));
        var requests = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests++;
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
        final checker = PronunciationChecker(
          recorder: _FileRecorder(ready.future),
          client: PronunciationRestClient(dio: dio),
        );
        addTearDown(checker.dispose);
        await checker.start();
        final checking = checker.stop(expected: 'ا');
        expect(checker.isChecking.value, isTrue);
        if (reset) {
          checker.reset();
        } else {
          checker.dispose();
        }
        ready.complete(file);
        expect(await checking, isNull);
        expect(requests, 0);
        expect(checker.error.value, isNull);
      },
    );
  }

  test('пропуск во время разрешения микрофона не оставляет запись', () async {
    final recorder = _DelayedRecorder();
    final checker = PronunciationChecker(recorder: recorder);
    addTearDown(checker.dispose);

    final starting = checker.start();
    checker.reset();
    recorder.ready.complete(true);
    await starting;

    expect(recorder.stopCount, 1);
    expect(checker.isRecording.value, isFalse);
    expect(checker.isChecking.value, isFalse);
    expect(checker.error.value, isNull);
  });

  test('пропуск останавливает уже начатую запись', () async {
    final recorder = _DelayedRecorder()..ready.complete(true);
    final checker = PronunciationChecker(recorder: recorder);
    addTearDown(checker.dispose);
    await checker.start();
    expect(checker.isRecording.value, isTrue);

    checker.reset();
    expect(checker.isRecording.value, isFalse);
    await checker.start();
    expect(recorder.stopCount, 1);
    expect(checker.isRecording.value, isTrue);
    checker.reset();
  });

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

  for (final (status, message) in [
    (200, 'Не удалось прочитать ответ сервера'),
    (404, 'Проверка слогов пока недоступна на сервере'),
  ]) {
    test(
      'ответ $status без результата слога остаётся техническим сбоем',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'checker_syllable',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/voice.m4a',
        ).writeAsBytes([1]);
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        addTearDown(() => dio.close(force: true));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final response = Response(
                requestOptions: options,
                statusCode: status,
                data: {},
              );
              if (status == 200) {
                handler.resolve(response);
              } else {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: response,
                    type: DioExceptionType.badResponse,
                  ),
                );
              }
            },
          ),
        );
        final checker = PronunciationChecker(
          recorder: _FileRecorder(Future.value(file)),
          client: PronunciationRestClient(dio: dio),
        );
        addTearDown(checker.dispose);
        await checker.start();
        expect(await checker.stopSyllable(expected: 'بِ'), isNull);
        expect(checker.syllableResult.value, isNull);
        expect(checker.error.value, message);
        expect(
          checker.failure.value,
          PronunciationFailureKind.serviceUnavailable,
        );
        expect(checker.isChecking.value, isFalse);
      },
    );
  }

  test('постоянный запрет показывает путь в настройки', () async {
    final permission = _DeniedPermission();
    final checker = PronunciationChecker(
      recorder: VoiceRecorder(permission: permission),
    );
    addTearDown(checker.dispose);

    await checker.start();
    expect(checker.isRecording.value, isFalse);
    expect(checker.failure.value, PronunciationFailureKind.microphoneDenied);
    expect(checker.microphoneSettingsRequired.value, isTrue);

    await checker.openMicrophoneSettings();
    expect(permission.settingsOpenCount, 1);
  });
}

class _DeniedPermission extends MicrophonePermission {
  int settingsOpenCount = 0;

  @override
  Future<MicrophonePermissionResult> request() async =>
      MicrophonePermissionResult.settingsRequired;

  @override
  Future<bool> openSettings() async {
    settingsOpenCount++;
    return true;
  }
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

class _FileRecorder extends VoiceRecorder {
  _FileRecorder(this.file);
  final Future<File?> file;

  @override
  Future<bool> start() async => true;

  @override
  Future<File?> stop() => file;
}
