// Настоящий HTTP защищает общий контракт, Unicode и исходные байты записи.
// Чужая единица, неполный ответ и противоречивый вердикт не меняют прогресс.
// Исходный текст модели сохраняется даже при зачёте слова с лишней ه.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arabic_tajweed_app/data/rest/api_exception.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_rest_client.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_check.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late PronunciationRestClient client;
  late Directory directory;
  late File audio;
  late Map<String, dynamic> response;
  late Completer<(Uri, String, String)> received;
  var statusCode = 200;
  const target = PronunciationTarget(
    type: PronunciationUnitType.syllable,
    id: 'ba.kasra',
    expected: 'بِ',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pronunciation_api');
    audio = await File(
      '${directory.path}/voice.m4a',
    ).writeAsBytes([0, 1, 2, 3, 127, 255]);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    client = PronunciationRestClient(dio: dio);
    statusCode = 200;
    response = {
      'version': 1,
      'target': target.toJson(),
      'heard': 'بِ',
      'status': 'matched',
      'checks': [
        {'code': 'letter', 'matched': true},
        {'code': 'haraka', 'matched': true},
      ],
      'hint': 'Верно: ба с касрой.',
      'recording': null,
      'isStub': false,
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

  for (final type in [
    PronunciationUnitType.letter,
    PronunciationUnitType.syllable,
    PronunciationUnitType.word,
    'madd',
  ]) {
    test(
      '$type отправляется общим multipart и принимает явную заглушку',
      () async {
        final requested = PronunciationTarget(
          type: type,
          id: 'test.$type',
          expected: 'بِكَ',
        );
        response.addAll({
          'target': requested.toJson(),
          'heard': null,
          'checks': [],
          'isStub': true,
        });
        final check = await client.check(audio: audio, target: requested);
        final (uri, method, body) = await received.future;
        expect(method, 'POST');
        expect(uri.path, '/pronunciation/check');
        expect(uri.queryParameters, isEmpty);
        expect(
          body,
          contains(latin1.decode(utf8.encode(jsonEncode(requested.toJson())))),
        );
        expect(body, contains('name="audio"; filename="voice.m4a"'));
        expect(body, contains(latin1.decode(await audio.readAsBytes())));
        expect(check.matched, isTrue);
        expect(check.isStub, isTrue);
        expect(check.heard, isNull);
        expect(check.feedbackTitle, 'Запись принята');
      },
    );
  }
  test('ошибка огласовки отличается от неразборчивой записи', () async {
    response.addAll({
      'heard': 'بَ',
      'status': 'mismatch',
      'checks': [
        {'code': 'letter', 'matched': true},
        {'code': 'haraka', 'matched': false},
      ],
    });
    final check = await client.check(audio: audio, target: target);
    expect(check.harakaMatched, isFalse);
    expect(check.canEvaluate, isTrue);
    expect(check.feedbackTitle, 'Буква верная, огласовка отличается');
  });
  test('успех слова сохраняет исходное распознавание с лишней ه', () async {
    const word = PronunciationTarget(
      type: PronunciationUnitType.word,
      id: 'word.kataba',
      expected: 'كَتَبَ',
    );
    response.addAll({
      'target': word.toJson(),
      'heard': word.expected,
      'rawHeard': '  كَتَبَه\n',
      'checks': [],
    });
    final check = await client.check(audio: audio, target: word);
    expect(check.matched, isTrue);
    expect(check.heard, word.expected);
    expect(check.rawHeard, '  كَتَبَه\n');
  });
  test('unclear не получает учебную оценку', () async {
    response.addAll({
      'heard': null,
      'status': 'unclear',
      'checks': [
        {'code': 'letter', 'matched': null},
        {'code': 'haraka', 'matched': null},
      ],
      'recording': {
        'speechFrom': .1,
        'loudnessDb': -38,
        'clarityDb': 5,
        'warning': 'тихо',
      },
    });
    expect(
      (await client.check(audio: audio, target: target)).canEvaluate,
      isFalse,
    );
  });
  for (final (name, change) in <(String, void Function(Map<String, dynamic>))>[
    ('другой тип', (json) => json['target']['type'] = 'letter'),
    ('другой атом', (json) => json['target']['id'] = 'another'),
    ('другое чтение', (json) => json['target']['expected'] = 'بَ'),
    ('неизвестная версия', (json) => json['version'] = 2),
    ('неизвестный статус', (json) => json['status'] = 'ok'),
    ('противоречивый успех', (json) => json['checks'][1]['matched'] = false),
    (
      'нет проверки огласовки',
      (json) => json['checks'] = [
        {'code': 'letter', 'matched': true},
      ],
    ),
    ('нет heard', (json) => json.remove('heard')),
    ('нет признака заглушки', (json) => json.remove('isStub')),
    ('оценка неразборчивой записи', (json) => json['status'] = 'unclear'),
    (
      'успех с предупреждением',
      (json) => json['recording'] = {
        'speechFrom': .1,
        'loudnessDb': -38,
        'clarityDb': 5,
        'warning': 'шумно',
      },
    ),
    ('заглушка выдумывает распознавание', (json) => json['isStub'] = true),
  ]) {
    test('$name отвергается', () async {
      change(response);
      await expectLater(
        client.check(audio: audio, target: target),
        throwsA(anyOf(isA<Exception>(), isA<Error>())),
      );
    });
  }
  test('отсутствие роута — техническая ошибка', () async {
    statusCode = 404;
    response = {
      'error': {'code': 'not_found', 'message': 'Метод не найден'},
    };
    await expectLater(
      client.check(audio: audio, target: target),
      throwsA(isA<NotFoundException>()),
    );
  });
}
