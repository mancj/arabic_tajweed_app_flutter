// Настоящий локальный HTTP-сервер защищает контракт: огласовка должна попасть
// в query без потерь, а файл — в multipart audio. Нельзя превратить плохую
// запись, неполный или противоречивый JSON в правильный/неправильный ответ.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arabic_tajweed_app/data/rest/api_exception.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_rest_client.dart';
import 'package:arabic_tajweed_app/data/rest/syllable_check.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late PronunciationRestClient client;
  late Directory directory;
  late File audio;
  late Map<String, Object?> response;
  late Completer<(Uri, String, String)> received;
  var statusCode = 200;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('syllable_api');
    audio = await File(
      '${directory.path}/voice.m4a',
    ).writeAsBytes([0, 1, 2, 3, 127, 255]);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    client = PronunciationRestClient(dio: dio);
    statusCode = 200;
    response = {
      'ожидалось': 'بِ',
      'услышано': 'بِ',
      'статус': 'matched',
      'буква_совпала': true,
      'огласовка_совпала': true,
      'подсказка': 'Верно: ба с касрой.',
    };
    received = Completer<(Uri, String, String)>();
    server.listen((request) async {
      final bytes = await request.fold<List<int>>(
        [],
        (all, part) => all..addAll(part),
      );
      received.complete((request.uri, request.method, latin1.decode(bytes)));
      request.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(response));
      await request.response.close();
    });
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test('POST сохраняет касру и передаёт исходные байты файла', () async {
    final check = await client.checkSyllable(audio: audio, expected: 'بِ');
    final (uri, method, body) = await received.future;
    expect(method, 'POST');
    expect(uri.path, '/syllable');
    expect(uri.queryParameters, {'expected': 'بِ'});
    expect(body, contains('name="audio"; filename="voice.m4a"'));
    expect(body, contains(latin1.decode(await audio.readAsBytes())));
    expect(check.matched, isTrue);
    expect(check.harakaMatched, isTrue);
  });

  test('другая огласовка отличается от неразборчивой записи', () async {
    response.addAll({
      'услышано': 'بَ',
      'статус': 'mismatch',
      'огласовка_совпала': false,
      'подсказка': 'С касрой прочитайте «би».',
    });
    final check = await client.checkSyllable(audio: audio, expected: 'بِ');
    expect(check.status, SyllableCheckStatus.mismatch);
    expect(check.letterMatched, isTrue);
    expect(check.harakaMatched, isFalse);
    expect(check.canEvaluate, isTrue);
  });

  test('unclear не получает учебную оценку', () async {
    response.addAll({
      'услышано': null,
      'статус': 'unclear',
      'буква_совпала': null,
      'огласовка_совпала': null,
      'подсказка': 'Повторите запись ближе к микрофону.',
      'запись': {
        'речь_с': 0.1,
        'громкость_дБ': -38,
        'чистота_дБ': 5,
        'предупреждение': 'тихо',
      },
    });
    final check = await client.checkSyllable(audio: audio, expected: 'بِ');
    expect(check.canEvaluate, isFalse);
    expect(check.matched, isFalse);
    expect(check.letterMatched, isNull);
    expect(check.harakaMatched, isNull);
  });

  for (final (name, change) in <(String, void Function(Map<String, Object?>))>[
    ('ответ на другой слог', (json) => json['ожидалось'] = 'بَ'),
    ('противоречивый успех', (json) => json['огласовка_совпала'] = false),
    ('оценка неразборчивой записи', (json) => json['статус'] = 'unclear'),
    (
      'успех при предупреждении',
      (json) => json['запись'] = {
        'речь_с': 0.1,
        'громкость_дБ': -38,
        'чистота_дБ': 5,
        'предупреждение': 'шумно',
      },
    ),
  ]) {
    test('$name отвергается', () async {
      change(response);
      await expectLater(
        client.checkSyllable(audio: audio, expected: 'بِ'),
        throwsFormatException,
      );
    });
  }

  test('пропущенная проверка огласовки не заменяется false', () async {
    response.remove('огласовка_совпала');
    await expectLater(
      client.checkSyllable(audio: audio, expected: 'بِ'),
      throwsA(isA<Exception>()),
    );
  });

  test('отсутствующий endpoint не даёт фиктивный результат', () async {
    statusCode = 404;
    response = {'ошибка': 'Метод не найден'};
    await expectLater(
      client.checkSyllable(audio: audio, expected: 'بِ'),
      throwsA(isA<NotFoundException>()),
    );
  });
}
