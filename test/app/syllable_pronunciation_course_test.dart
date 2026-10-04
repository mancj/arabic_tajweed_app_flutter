// Проверяет настоящую цепочку урока, записи и HTTP-клиента: слог нельзя
// отправить в /letter или потерять его огласовку. Неразборчивая запись не
// тратит попытку, две ошибки дают разбор, исправление сохраняет номер попытки.
// Технический пропуск не создаёт успех и убирает голос до конца занятия.
// Исчерпанный голосовой бюджет не должен прерывать объяснения новых знаков.
import 'dart:io';
import 'dart:async';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_pronunciation_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_rest_client.dart';
import 'package:arabic_tajweed_app/data/voice_recorder.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData, Response;

import '../helpers/plugin_mocks.dart';
import '../helpers/text_asset_bundle.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  late ProgressDatabase database;
  late LessonController controller;
  late Directory directory;
  late Dio dio;
  late _Audio audio;
  late List<RequestOptions> requests;
  var verdict = 'matched';
  var httpStatus = 200;

  setUp(() async {
    mockPlatformPlugins();
    database = ProgressDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('syllable_course');
    audio = _Audio();
    requests = [];
    verdict = 'matched';
    httpStatus = 200;
    dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final expected = options.queryParameters['expected'] as String;
          final mismatch = verdict == 'mismatch';
          final unclear = verdict == 'unclear';
          final response = Response(
            requestOptions: options,
            statusCode: httpStatus,
            data: {
              'ожидалось': expected,
              'услышано': unclear
                  ? null
                  : mismatch
                  ? expected.replaceAll(
                      RegExp('[َُِ]'),
                      expected.contains('َ') ? 'ِ' : 'َ',
                    )
                  : expected,
              'статус': verdict,
              'буква_совпала': unclear ? null : true,
              'огласовка_совпала': unclear ? null : !mismatch,
              'подсказка': unclear
                  ? 'Повторите запись ближе к микрофону.'
                  : mismatch
                  ? 'Обратите внимание на огласовку.'
                  : 'Верное чтение слога.',
            },
          );
          if (httpStatus == 200) {
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
  });

  tearDown(() async {
    Get.reset();
    dio.close(force: true);
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 5; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> mount(
    WidgetTester tester, {
    String topicId = 'm.haraka.group1',
    LearningRules rules = const LearningRules(),
    bool prepareVoice = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final now = DateTime(2026, 10, 3);
      await database.appendAll([
        for (final topic in curriculum.topics.takeWhile((t) => t.id != topicId))
          for (final id in topic.counterOf)
            if (byId[id]!.kind == AtomKind.concept)
              AtomIntroduced(atomId: id, sessionId: 1, at: now)
            else
              KnowledgeConfirmed(atomId: id, sessionId: 1, at: now),
      ]);
      controller = LessonController(
        rules: rules,
        database: database,
        curriculum: curriculum,
        topicId: topicId,
        explanationBundle: TextAssetBundle.forCurriculum(curriculum),
        audio: audio,
        recorder: _Recorder(directory),
        pronunciation: PronunciationRestClient(dio: dio),
        shapeLoader: (asset) async => TracingShapeSvg.parse(
          File(
            'assets/svg/${asset.contains('/') ? asset : 'alphabet/$asset'}.svg',
          ).readAsStringSync(),
          id: asset,
        ),
      );
      final ready = Completer<void>();
      final subscription = controller.stage.listen((stage) {
        if (stage != LessonStage.loading && !ready.isCompleted) {
          ready.complete();
        }
      });
      Get.put(controller);
      await ready.future.timeout(const Duration(seconds: 5));
      await subscription.cancel();
      expect(controller.loadError.value, isNull);
      if (!prepareVoice) return;
      if (controller.stage.value == LessonStage.intro) {
        final introduced = controller.introAtom!;
        await controller.nextIntro();
        expect(controller.current!.atom, introduced);
      } else {
        final introduced = controller.card.value!;
        await controller.dismissCard();
        expect(controller.current!.atom, introduced);
      }
      expect(controller.current!.mode, ExerciseMode.saySyllable);
      expect(controller.card.value, isNull);
    });
    audio.played.clear();
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    if (!prepareVoice) return;
    expect(find.byType(SyllablePronunciationExercise), findsOneWidget);
    expect(find.text('Прочитайте этот слог вслух'), findsOneWidget);
    expect(find.byType(PlayControl), findsNothing);
    expect(audio.played, isEmpty);
    expect(controller.canSubmit, isFalse);
  }

  Future<void> record(WidgetTester tester) async {
    await tester.runAsync(controller.startRecording);
    expect(controller.pronunciation.isRecording.value, isTrue);
    await tester.runAsync(controller.stopRecording);
    await settle(tester);
  }

  Future<List<ProgressEvent>> events(WidgetTester tester) async =>
      (await tester.runAsync(database.readAll))!
          .whereType<ProgressEvent>()
          .where((event) => event.mode == ExerciseMode.saySyllable)
          .toList();

  Future<void> press(WidgetTester tester, String text) async {
    final button = find.text(text);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  testWidgets('две попытки, unclear и исправление работают в курсе', (
    tester,
  ) async {
    await mount(tester);
    final exercise = controller.current!;
    verdict = 'unclear';
    await record(tester);
    expect(find.text('Не удалось уверенно разобрать слог'), findsOneWidget);
    expect(await events(tester), isEmpty);
    verdict = 'mismatch';
    await record(tester);
    expect(controller.wasWrong.value, isFalse);
    expect(await events(tester), isEmpty);
    expect(find.text('Буква верная, огласовка отличается'), findsOneWidget);
    await record(tester);
    expect(controller.wasWrong.value, isTrue);
    expect((await events(tester)).single.correct, isFalse);
    await press(tester, 'Попробовать ещё раз');
    verdict = 'matched';
    await record(tester);
    expect(find.text('Слог прочитан правильно'), findsOneWidget);
    final log = await events(tester);
    expect(log, hasLength(2));
    expect(log.map((event) => event.atomId).toSet(), {exercise.atom.id});
    expect(log.last.correct, isTrue);
    expect(log.last.attempt, 2);
    expect(log.last.isClean, isFalse);
    expect(requests, hasLength(4));
    for (final request in requests) {
      expect(request.path, '/syllable');
      expect(request.queryParameters, {'expected': exercise.atom.display});
      expect((request.data as FormData).files.single.key, 'audio');
    }
    await press(tester, 'Продолжить');
    expect(controller.pronunciation.syllableResult.value, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('недоступный метод пропускается без события прогресса', (
    tester,
  ) async {
    await mount(tester);
    httpStatus = 404;
    await record(tester);
    expect(
      find.text('Проверка слогов пока недоступна на сервере'),
      findsOneWidget,
    );
    expect(await events(tester), isEmpty);
    await press(tester, 'Продолжить без произношения');
    expect(controller.rules.requirePronunciation, isFalse);
    await tester.runAsync(controller.finishLessonCorrectly);
    expect(controller.stage.value, LessonStage.finished);
    expect(await events(tester), isEmpty);
    expect(requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('на ба голос идёт сразу после знакомства и сохраняет режим', (
    tester,
  ) async {
    await mount(tester, topicId: 'm.haraka.signs');
    final atom = controller.current!.atom;
    expect(atom.id, 'haraka.fatha');
    verdict = 'mismatch';
    await record(tester);
    expect(controller.wasWrong.value, isFalse);
    await tester.runAsync(() => controller.answerCorrectly());
    await settle(tester);
    expect(find.text('Слог прочитан правильно'), findsOneWidget);
    final log = await events(tester);
    expect(log.single.atomId, atom.id);
    expect(log.single.isClean, isTrue);
    await press(tester, 'Продолжить');
    expect(controller.stage.value, LessonStage.intro);
    expect(controller.introAtom!.id, 'haraka.kasra');
    expect(requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('предел голоса не обрывает объяснения нового материала', (
    tester,
  ) async {
    await mount(
      tester,
      topicId: 'm.haraka.signs',
      rules: const LearningRules(syllablePronunciationMaxPercent: 5),
      prepareVoice: false,
    );
    await tester.runAsync(() async {
      while (controller.stage.value == LessonStage.intro) {
        await controller.nextIntro();
      }
      await controller.finishLessonCorrectly();
    });
    await settle(tester);
    expect(controller.stage.value, LessonStage.finished);
    expect(await events(tester), hasLength(1));
    final log = (await tester.runAsync(database.readAll))!;
    expect(
      log.whereType<AtomIntroduced>().map((entry) => entry.atomId),
      containsAll(['haraka.fatha', 'haraka.kasra', 'haraka.damma']),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Recorder extends VoiceRecorder {
  _Recorder(this.directory);
  final Directory directory;
  var recordings = 0;
  @override
  final ValueNotifier<double> level = ValueNotifier(0);
  @override
  Future<bool> start() async => true;
  @override
  Future<File?> stop() => File(
    '${directory.path}/voice${++recordings}.m4a',
  ).writeAsBytes([1, 2, 3]);
  @override
  void dispose() => level.dispose();
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  final played = <String?>[];
  @override
  Future<void> playAsset(String? asset) async => played.add(asset);
  @override
  Future<void> toggleAsset(String? asset) async => played.add(asset);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => track.dispose();
}
