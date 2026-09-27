import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Первая тема огласовок содержит только объяснение. После окончания букв
/// она должна перейти к первым знакам в том же занятии без старых заданий.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
  ]);

  test(
    'объяснение огласовок сразу переходит к практике нового раздела',
    () async {
      final database = ProgressDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final today = DateTime(2026, 9, 26, 12);
      final oldDay = DateTime(2026, 9, 25, 12);
      final clock = AppClock(systemNow: () => today);
      final repository = ProgressRepository(
        database: database,
        letterFormIds: curriculum.letterFormIds,
        baseLetterIds: curriculum.baseLetterIds,
        now: () => today,
      );
      final ids = curriculum.topics
          .where((topic) => topic.stage == 1)
          .expand((topic) => topic.counterOf)
          .toSet();
      await repository.recordAll([
        for (final node in curriculum.nodes)
          if (ids.contains(node.atom.id))
            if (node.atom.kind == AtomKind.concept)
              AtomIntroduced(atomId: node.atom.id, sessionId: 1, at: oldDay)
            else
              KnowledgeConfirmed(
                atomId: node.atom.id,
                sessionId: 1,
                at: oldDay,
              ),
      ]);
      await repository.finishSession(
        sessionId: 2,
        purpose: LessonPurpose.alphabetCheckpoint,
        exerciseCount: 20,
        firstTryCorrect: 20,
        checkpointLetters: 28,
        at: oldDay,
      );
      final context = CurriculumContext(
        progress: await repository.progress(),
        formsByLetter: curriculum.formsByLetter,
      );
      final plan = LessonPlanner(curriculum: curriculum).plan(
        ctx: context,
        sessionId: await repository.nextSessionId(),
        sessionsWithoutNew: await repository.sessionsWithoutNew(),
        pacing: await repository.pacing(),
      );
      expect(plan.topicId, 'm.haraka.intro');
      expect(plan.reviewAtoms, isEmpty);
      expect(plan.spacedReview, isEmpty);

      final controller = LessonController(
        database: database,
        curriculum: curriculum,
        plan: plan,
        continuePlanning: true,
        clock: clock,
        shapeLoader: (_) async =>
            throw UnsupportedError('Холст не нужен для проверки порядка'),
      );
      addTearDown(controller.onClose);
      final ready = Completer<void>();
      final subscription = controller.stage.listen((stage) {
        if (stage != LessonStage.loading && !ready.isCompleted) {
          ready.complete();
        }
      });
      controller.onInit();
      await ready.future.timeout(const Duration(seconds: 5));
      await subscription.cancel();
      expect(controller.loadError.value, isNull);
      expect(controller.introAtom?.id, 'concept.haraka');

      await controller.nextIntro();
      expect(controller.stage.value, LessonStage.intro);
      expect(controller.introAtom?.id, 'haraka.fatha');

      var steps = 0;
      while (controller.stage.value != LessonStage.finished) {
        expect(++steps, lessThan(80));
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
          continue;
        }
        while (controller.card.value != null) {
          await controller.dismissCard();
        }
        await controller.answerCorrectly(advance: true);
      }
      final results = (await database.readAll())
          .whereType<ProgressEvent>()
          .where((entry) => entry.sessionId == 3)
          .toList();
      final stage2Ids = curriculum.topics
          .where((topic) => topic.stage == 2)
          .expand((topic) => topic.counterOf)
          .toSet();
      expect(results.length, greaterThanOrEqualTo(8));
      expect(
        results.every((entry) => stage2Ids.contains(entry.atomId)),
        isTrue,
      );
      final summaries = await database.readSessionSummaries();
      expect(
        summaries.where((summary) => summary.sessionId == 3),
        hasLength(1),
      );
    },
  );
}
