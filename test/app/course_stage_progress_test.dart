// Защищает главную карточку от возвращения счётчика «28 из 28» после
// перехода к огласовкам. Раздел и число освоенных блоков должны совпадать
// с «Моим путём», даже в повторении без topicId и после ошибки в старой теме.
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/course/course_controller.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_dashboard.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final today = DateTime(2026, 10, 3, 12);
  final yesterday = today.subtract(const Duration(days: 1));
  late ProgressDatabase database;
  late CourseController controller;

  setUp(() {
    database = ProgressDatabase(NativeDatabase.memory());
    controller = CourseController(
      database: database,
      curriculum: curriculum,
      clock: AppClock(systemNow: () => today),
    );
  });
  tearDown(() async {
    controller.onClose();
    Get.reset();
    await database.close();
  });

  Future<void> confirmStages(Set<int> stages) async {
    final ids = curriculum.topics
        .where((topic) => stages.contains(topic.stage))
        .expand((topic) => topic.counterOf)
        .toSet();
    await database.appendAll([
      for (final node in curriculum.nodes)
        if (ids.contains(node.atom.id))
          if (node.atom.kind == AtomKind.concept)
            AtomIntroduced(atomId: node.atom.id, sessionId: 1, at: yesterday)
          else
            KnowledgeConfirmed(
              atomId: node.atom.id,
              sessionId: 1,
              at: yesterday,
            ),
    ]);
    await database.finishSession(
      sessionId: 1,
      purpose: LessonPurpose.alphabetCheckpoint,
      exerciseCount: 20,
      firstTryCorrect: 20,
      checkpointLetters: 28,
      at: yesterday,
    );
  }

  test(
    'первый раздел считает буквы, а переход сразу показывает огласовки',
    () async {
      await controller.refreshBoard();
      expect(controller.loadError.value, isNull);
      expect(controller.currentStage, 1);
      expect(controller.pathProgress.summary, 'Освоено букв: 0 из 28');
      await confirmStages({1});
      await controller.refreshBoard();
      expect(controller.loadError.value, isNull);
      expect(controller.nextPlan.value!.topicId, 'm.haraka.intro');
      expect(controller.currentStage, 2);
      expect(controller.knownLetters, 28);
      expect(controller.pathProgress.done, 0);
      expect(
        controller.pathProgress.total,
        curriculum.topics.where((t) => t.stage == 2).length,
      );
      expect(controller.pathProgress.unit, 'блоков освоено');
      expect(controller.pathProgress.fraction, 0);
    },
  );

  test('после огласовок счётчик переходит к связкам и словам', () async {
    await confirmStages({1, 2});
    await controller.refreshBoard();
    expect(controller.loadError.value, isNull);
    expect(controller.currentStage, 3);
    expect(controller.pathProgress.done, 0);
    expect(
      controller.pathProgress.total,
      curriculum.topics.where((t) => t.stage == 3).length,
    );
    expect(controller.pathProgress.summary, startsWith('Освоено блоков: 0 из'));
  });

  testWidgets('повтор без темы показывает блоки текущего раздела и их долю', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.runAsync(() async {
      await confirmStages({1});
      await database.appendAll([
        AtomIntroduced(atomId: 'concept.haraka', sessionId: 2, at: yesterday),
        for (final id in ['haraka.fatha', 'haraka.kasra', 'haraka.damma'])
          KnowledgeConfirmed(atomId: id, sessionId: 2, at: yesterday),
      ]);
      await controller.refreshBoard();
    });
    expect(controller.loadError.value, isNull);
    controller.nextPlan.value = const LessonPlan(
      template: LessonTemplate.review,
      newAtoms: [],
      reviewAtoms: ['haraka.fatha', 'haraka.kasra', 'haraka.damma'],
      purpose: LessonPurpose.mixedReview,
      reason: 'повтор огласовок без отдельной темы',
    );
    expect(controller.currentTopic, isNull);
    expect(controller.currentStage, 2);
    final progress = controller.pathProgress;
    expect(progress.done, 2);
    expect(progress.done, controller.byStage[2]!.where((t) => t.isDone).length);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: CourseOverview(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('${progress.done} / ${progress.total}'), findsOneWidget);
    expect(find.text('28 / 28'), findsNothing);
    expect(find.text('блоков освоено\nОгласовки'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, progress.done / progress.total);
    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('Огласовки. ${progress.summary}')),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await database.append(
        ProgressEvent(
          atomId: 'ba.isolated',
          sessionId: 3,
          at: today,
          mode: ExerciseMode.soundToLetter,
          correct: false,
          attempt: 1,
          fastEnough: true,
        ),
      );
      await controller.refreshBoard();
    });
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: CourseOverview(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.knownLetters, 27);
    expect(controller.currentStage, 2);
    expect(controller.pathProgress.done, 2);
    expect(find.text('блоков освоено\nОгласовки'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      ring.value,
    );
    semantics.dispose();
  });
}
