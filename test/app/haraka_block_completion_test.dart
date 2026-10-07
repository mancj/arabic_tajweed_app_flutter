// Реальный контроллер должен провести все огласовки до соединений: добор,
// обязательное письмо и ограниченный голос не должны зациклить последний
// слог либо открыть следующий раздел раньше. Проверяем журнал в базе,
// включая успешные ответы в составных заданиях и вариант без произношения.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  final harakaIds = curriculum.topics
      .where((topic) => topic.stage == 2)
      .expand((topic) => topic.counterOf)
      .toSet();

  for (final voice in [true, false]) {
    test('весь блок завершается и открывает соединения; голос=$voice', () async {
      final database = ProgressDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final rules = LearningRules(requirePronunciation: voice);
      var today = DateTime(2026, 10, 1, 12);
      final clock = AppClock(systemNow: () => today);
      final repository = ProgressRepository(
        database: database,
        rules: rules,
        letterFormIds: curriculum.letterFormIds,
        baseLetterIds: curriculum.baseLetterIds,
        now: () => today,
      );
      await repository.recordAll([
        for (final topic in curriculum.topics.where(
          (topic) => topic.stage == 1,
        ))
          for (final id in topic.counterOf)
            if (byId[id]!.kind == AtomKind.concept)
              AtomIntroduced(atomId: id, sessionId: 1, at: today)
            else
              KnowledgeConfirmed(atomId: id, sessionId: 1, at: today),
      ]);
      await repository.finishSession(
        sessionId: 2,
        purpose: LessonPurpose.alphabetCheckpoint,
        exerciseCount: 20,
        firstTryCorrect: 20,
        checkpointLetters: 28,
        at: today,
      );
      final planner = LessonPlanner(curriculum: curriculum, rules: rules);
      final board = TopicBoard(curriculum, rules: rules);
      var reachedConnections = false;
      for (var lesson = 0; lesson < 70; lesson++) {
        today = today.add(const Duration(days: 1));
        await repository.recompute();
        final context = CurriculumContext(
          progress: await repository.progress(),
          formsByLetter: curriculum.formsByLetter,
        );
        if (planner.activeStage(context) == 3) {
          reachedConnections = true;
          for (final id in harakaIds) {
            expect(board.isDone(id, context), isTrue, reason: id);
            if (byId[id]!.kind != AtomKind.concept) {
              expect(context.progress[id]!.weak, isFalse, reason: id);
              expect(
                context.progress[id]!.successfulModes,
                containsAll(rules.requiredPracticeModes(byId[id]!)),
                reason: id,
              );
            }
          }
          break;
        }
        final plan = planner.plan(
          ctx: context,
          sessionId: await repository.nextSessionId(),
          sessionsWithoutNew: await repository.sessionsWithoutNew(),
          pacing: await repository.pacing(),
        );
        final controller = LessonController(
          database: database,
          curriculum: curriculum,
          rules: rules,
          plan: plan,
          continuePlanning: true,
          clock: clock,
          audio: _Audio(),
          shapeLoader: (_) async => throw UnsupportedError('Ответ задаёт тест'),
        );
        final ready = Completer<void>();
        final subscription = controller.stage.listen((stage) {
          if (stage != LessonStage.loading && !ready.isCompleted) {
            ready.complete();
          }
        });
        try {
          controller.onInit();
          await ready.future.timeout(const Duration(seconds: 5));
          expect(controller.loadError.value, isNull);
          var steps = 0;
          var spoken = 0;
          while (controller.stage.value != LessonStage.finished) {
            expect(
              ++steps,
              lessThan(150),
              reason:
                  '${plan.reason}; ${controller.stage.value}; '
                  '${controller.current?.atom.id}/${controller.current?.mode}; '
                  'intro=${controller.introAtom?.id}; '
                  'card=${controller.card.value?.id}; '
                  'done=${controller.completedExerciseCount}',
            );
            if (controller.stage.value == LessonStage.intro) {
              await controller.nextIntro();
              continue;
            }
            while (controller.card.value != null) {
              await controller.dismissCard();
            }
            if (controller.current!.mode == ExerciseMode.syllableBuild) {
              expect(controller.syllableBuildEvaluation.value, isNull);
            }
            if (controller.current!.mode.isPronunciation) spoken++;
            await controller.answerCorrectly(advance: true);
          }
          final count = controller.completedExerciseCount;
          expect(count, greaterThan(0), reason: plan.reason);
          expect(count, lessThanOrEqualTo(rules.tasksPerSession));
          expect(controller.progress, 1);
          expect(
            spoken,
            voice ? lessThanOrEqualTo(max(1, count * 15 ~/ 100)) : 0,
          );
        } finally {
          await subscription.cancel();
          controller.onClose();
        }
      }
      expect(
        reachedConnections,
        isTrue,
        reason: 'Правильные ответы не застревают',
      );
    });
  }
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
