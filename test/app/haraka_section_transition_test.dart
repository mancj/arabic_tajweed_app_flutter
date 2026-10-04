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
/// она должна перейти к первым знакам в том же занятии. Из алфавита
/// возвращаются только две сборки форм, без обычных заданий букв.
/// На следующий день новые задания должны переносить знаки на другие буквы,
/// иначе отдельный блок слогов ба снова продублирует первый урок.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
  ]);

  test('первый урок объясняет знаки, следующий вводит другие буквы', () async {
    final database = ProgressDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var today = DateTime(2026, 9, 26, 12);
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
            KnowledgeConfirmed(atomId: node.atom.id, sessionId: 1, at: oldDay),
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

    Future<LessonController> start(LessonPlan plan) async {
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
      return controller;
    }

    Future<void> finish(LessonController controller) async {
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
    }

    final controller = await start(plan);
    expect(controller.introAtom?.id, 'concept.haraka');
    await controller.nextIntro();
    expect(controller.stage.value, LessonStage.intro);
    expect(controller.introAtom?.id, 'haraka.fatha');
    await finish(controller);
    final results = (await database.readAll())
        .whereType<ProgressEvent>()
        .where((entry) => entry.sessionId == 3)
        .toList();
    final stage2Ids = curriculum.topics
        .where((topic) => topic.stage == 2)
        .expand((topic) => topic.counterOf)
        .toSet();
    expect(results.length, greaterThanOrEqualTo(8));
    final oldResults = results
        .where((entry) => !stage2Ids.contains(entry.atomId))
        .toList();
    expect(oldResults, isNotEmpty);
    expect(oldResults.map((entry) => entry.mode).toSet(), {
      ExerciseMode.positionToForm,
    });
    final atomsById = {
      for (final node in curriculum.nodes) node.atom.id: node.atom,
    };
    expect(
      oldResults.map((entry) => atomsById[entry.atomId]!.letterId).toSet(),
      hasLength(2),
    );
    final summaries = await database.readSessionSummaries();
    expect(summaries.where((summary) => summary.sessionId == 3), hasLength(1));

    today = today.add(const Duration(days: 1));
    await repository.recompute();
    final nextPlan = LessonPlanner(curriculum: curriculum).plan(
      ctx: CurriculumContext(
        progress: await repository.progress(),
        formsByLetter: curriculum.formsByLetter,
      ),
      sessionId: await repository.nextSessionId(),
      sessionsWithoutNew: await repository.sessionsWithoutNew(),
      pacing: await repository.pacing(),
    );
    expect(nextPlan.topicId, 'm.haraka.group1');
    expect(nextPlan.newAtoms.map((atom) => atom.letterId).toSet(), {
      'ta',
      'kaf',
      'dal',
      'ra',
    });
    await finish(await start(nextPlan));
    final introduced = (await database.readAll())
        .whereType<AtomIntroduced>()
        .where((entry) => entry.sessionId == 4)
        .map((entry) => entry.atomId)
        .toSet();
    expect(introduced, containsAll(nextPlan.newAtoms.map((atom) => atom.id)));
    expect(introduced.any((id) => id.startsWith('vowel.ba.')), isFalse);
  });
}
