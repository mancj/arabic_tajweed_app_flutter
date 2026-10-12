// Первые короткие занятия слов должны открывать следующий набор в тот же
// день. Проверяем настоящий контроллер, дневной темп, общий предел повторов
// при доборе и отсутствие новых результатов для старых букв и слогов.
import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/text_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  final topics = curriculum.topics.where((topic) => topic.stage == 3).toList();
  final day = DateTime(2026, 10, 11, 10);

  for (final voice in [true, false]) {
    test('короткие занятия проходят весь блок слов; голос=$voice', () async {
      final database = ProgressDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.appendAll([
        for (final topic in curriculum.topics.where((topic) => topic.stage < 3))
          for (final id in topic.counterOf)
            if (byId[id]!.kind == AtomKind.concept)
              AtomIntroduced(
                atomId: id,
                sessionId: 1,
                at: day.subtract(const Duration(days: 1)),
              )
            else
              KnowledgeConfirmed(
                atomId: id,
                sessionId: 1,
                at: day.subtract(const Duration(days: 1)),
              ),
      ]);
      await database.finishSession(
        sessionId: 1,
        purpose: LessonPurpose.alphabetCheckpoint,
        exerciseCount: 20,
        firstTryCorrect: 20,
        checkpointLetters: 28,
        at: day.subtract(const Duration(days: 1)),
      );

      final rules = LearningRules(requirePronunciation: voice);
      final fold = ProgressFold(
        rules: rules,
        letterFormIds: curriculum.letterFormIds,
        baseLetterIds: curriculum.baseLetterIds,
        wordAtomIds: curriculum.wordAtomIds,
      );
      var courseCompleted = false;
      for (var session = 2; session < 40 && !courseCompleted; session++) {
        final controller = LessonController(
          database: database,
          curriculum: curriculum,
          rules: rules,
          continuePlanning: true,
          clock: AppClock(systemNow: () => day),
          audio: _Audio(),
          explanationBundle: TextAssetBundle.forCurriculum(curriculum),
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
          while (controller.stage.value == LessonStage.intro) {
            await controller.nextIntro();
          }
          await controller.finishLessonCorrectly();
          expect(controller.stage.value, LessonStage.finished);
          expect(controller.completedExerciseCount, lessThanOrEqualTo(20));
          final answers = (await database.readAll())
              .whereType<ProgressEvent>()
              .where((answer) => answer.sessionId == session)
              .toList();
          expect(answers, isNotEmpty);
          expect(
            answers.every(
              (answer) => byId[answer.atomId]!.kind == AtomKind.word,
            ),
            isTrue,
          );
          expect(
            answers.map((answer) => answer.atomId).toSet().length,
            lessThanOrEqualTo(8),
          );
          for (final id in answers.map((answer) => answer.atomId).toSet()) {
            expect(
              answers
                  .where(
                    (answer) =>
                        answer.atomId == id && !answer.mode.isPronunciation,
                  )
                  .length,
              lessThanOrEqualTo(2),
            );
          }
          final ctx = CurriculumContext(
            progress: fold.fold(await database.readAll()),
            formsByLetter: curriculum.formsByLetter,
          );
          courseCompleted = TopicBoard(curriculum, rules: rules)
              .statuses(ctx)
              .where((status) => topics.contains(status.topic))
              .every((status) => status.isDone);
        } finally {
          await subscription.cancel();
          controller.onClose();
        }
      }
      expect(
        courseCompleted,
        isTrue,
        reason: 'Короткое повторение должно засчитываться в дневном цикле',
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
