// Выход без записи должен быть доступен у букв, знаков и слогов сразу.
// Пропуск не пишет ответ, не укорачивает доступное занятие и убирает голос
// из следующих уроков этого запуска. Новый запуск возвращает голосовой пробел.
// Причина технической недоступности не меняет срок отключения.
import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/microphone_permission.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late SharedPreferences storage;
  late PronunciationPreference preference;

  setUp(() async {
    mockPlatformPlugins();
    database = ProgressDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    storage = await SharedPreferences.getInstance();
    preference = PronunciationPreference(SharedPreferenceManager(storage));
  });
  tearDown(() async {
    Get.reset();
    await database.close();
  });

  Future<LessonController> start(
    String topicId,
    PronunciationPreference preference, {
    required bool continuePlanning,
  }) async {
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      topicId: topicId,
      continuePlanning: continuePlanning,
      explanationBundle: TextAssetBundle.forCurriculum(curriculum),
      pronunciationPreference: preference,
      audio: _Audio(),
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
    return controller;
  }

  Future<void> reachVoice(LessonController controller) async {
    for (var step = 0; step < 40; step++) {
      expect(controller.stage.value, isNot(LessonStage.finished));
      if (controller.stage.value == LessonStage.intro) {
        await controller.nextIntro();
        continue;
      }
      while (controller.card.value != null) {
        await controller.dismissCard();
      }
      if (controller.current!.mode.isPronunciation) return;
      await controller.answerCorrectly(advance: true);
    }
    fail('Произношение не появилось');
  }

  Future<void> finish(LessonController controller) async {
    while (controller.stage.value == LessonStage.intro) {
      await controller.nextIntro();
    }
    await controller.finishLessonCorrectly();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 5; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> seedPreviousTopics(String topicId) async {
    final at = DateTime(2026, 10, 4);
    await database.appendAll([
      for (final topic in curriculum.topics.takeWhile(
        (topic) => topic.id != topicId,
      ))
        for (final id in topic.counterOf)
          if (byId[id]!.kind == AtomKind.concept)
            AtomIntroduced(atomId: id, sessionId: 1, at: at)
          else
            KnowledgeConfirmed(atomId: id, sessionId: 1, at: at),
    ]);
  }

  for (final topicId in [
    curriculum.topics.first.id,
    'm.haraka.signs',
    'm.haraka.group1',
  ]) {
    for (final continuePlanning in [false, true]) {
      testWidgets(
        '$topicId: пропуск, замена заданий и новый запуск; добор=$continuePlanning',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(375, 812));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          late LessonController controller;
          await tester.runAsync(() async {
            await seedPreviousTopics(topicId);
            controller = await start(
              topicId,
              preference,
              continuePlanning: continuePlanning,
            );
            await reachVoice(controller);
          });
          await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
          await settle(tester);
          final target = controller.totalExercises;
          expect(controller.pronunciation.error.value, isNull);
          final skip = find.text('Продолжить без произношения');
          expect(skip, findsOneWidget);
          await tester.ensureVisible(skip);
          await tester.tap(skip);
          // Двойной тап не должен пропустить следующее обычное задание.
          await tester.runAsync(controller.optOutOfPronunciation);
          await settle(tester);
          expect(preference.isDisabled, isTrue);
          expect(controller.rules.requirePronunciation, isFalse);
          await tester.runAsync(() => finish(controller));
          await settle(tester);
          expect(controller.stage.value, LessonStage.finished);
          expect(controller.totalExercises, target);
          expect(controller.completedExerciseCount, target);
          expect(controller.firstTryCorrectCount, target - 1);
          final answers = (await tester.runAsync(
            database.readAll,
          ))!.whereType<ProgressEvent>().toList();
          expect(
            answers.where((answer) => answer.mode.isPronunciation),
            isEmpty,
          );
          expect(answers.every((answer) => answer.correct), isTrue);
          expect(controller.progress, 1);

          await tester.pumpWidget(const SizedBox.shrink());
          await Get.delete<LessonController>();
          await tester.runAsync(() async {
            final sameRun = await start(
              topicId,
              preference,
              continuePlanning: continuePlanning,
            );
            expect(sameRun.rules.requirePronunciation, isFalse);
            await finish(sameRun);
            final afterSameRun = (await database.readAll())
                .whereType<ProgressEvent>();
            expect(
              afterSameRun.where((answer) => answer.mode.isPronunciation),
              isEmpty,
            );
            await Get.delete<LessonController>();

            final restarted = PronunciationPreference(
              SharedPreferenceManager(storage),
            );
            await restarted.checkMicrophoneAccess(permission: _Permission());
            expect(restarted.isDisabled, isFalse);
            final nextRun = await start(
              topicId,
              restarted,
              continuePlanning: continuePlanning,
            );
            expect(nextRun.rules.requirePronunciation, isTrue);
            await reachVoice(nextRun);
            expect(nextRun.current!.mode.isPronunciation, isTrue);
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final failure in PronunciationFailureKind.values) {
    test('пропуск после $failure действует только до перезапуска', () async {
      const topicId = 'm.haraka.group1';
      await seedPreviousTopics(topicId);
      final controller = await start(
        topicId,
        preference,
        continuePlanning: false,
      );
      await reachVoice(controller);
      final before = (await database.readAll())
          .whereType<ProgressEvent>()
          .length;
      controller.pronunciation.failure.value = failure;
      controller.pronunciation.error.value = 'Проверка недоступна';
      await controller.optOutOfPronunciation();
      expect(preference.isDisabled, isTrue);
      expect(controller.rules.requirePronunciation, isFalse);
      expect(
        (await database.readAll()).whereType<ProgressEvent>(),
        hasLength(before),
      );
      await Get.delete<LessonController>();

      final restarted = PronunciationPreference(
        SharedPreferenceManager(storage),
      );
      await restarted.checkMicrophoneAccess(permission: _Permission());
      expect(restarted.isDisabled, isFalse);
    });
  }
}

class _Permission extends MicrophonePermission {
  @override
  Future<bool> isPermanentlyDenied() async => false;
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  @override
  Future<void> playAsset(String? asset) async {}
  @override
  Future<void> toggleAsset(String? asset) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => track.dispose();
}
