import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// PC-003: ошибка на уже пройденной букве сбрасывала чистую серию, после чего
/// добор состоял из одного теста. Одного режима недостаточно для `known`,
/// поэтому блок строился снова и одна буква могла занять всё занятие.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rules = LearningRules(requirePronunciation: false);
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  late ProgressDatabase database;
  late ProgressRepository repository;

  setUp(() {
    database = ProgressDatabase(NativeDatabase.memory());
    repository = ProgressRepository(
      database: database,
      rules: rules,
      letterFormIds: curriculum.letterFormIds,
    );
  });

  tearDown(() => database.close());

  test('добор любой базовой буквы меняет режим и соблюдает общий лимит', () {
    final baseLetters = curriculum.nodes
        .map((node) => node.atom)
        .where(
          (atom) =>
              atom.kind == AtomKind.letterForm &&
              atom.form == LetterForm.isolated &&
              atom.tracing != null,
        )
        .toList();
    expect(baseLetters.length, greaterThan(20));

    for (final target in baseLetters) {
      final progress = {
        for (final atom in baseLetters)
          atom.id: const AtomProgress(state: AtomState.introduced),
        target.id: const AtomProgress(
          state: AtomState.learning,
          successfulModes: {
            ExerciseMode.trace,
            ExerciseMode.traceFromMemory,
            ExerciseMode.soundToLetter,
          },
          hadActiveSuccess: true,
          lastSeenSession: 1,
        ),
      };
      final context = CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );
      final plan = LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: [target.id],
        reviewCounts: {target.id: 3},
        reason: 'regression PC-003',
      );
      final generator = ExerciseGenerator(curriculum: curriculum, rules: rules);
      final recovery = generator.build(plan: plan, ctx: context, sessionId: 2);

      expect(recovery, hasLength(3), reason: target.id);
      expect(
        recovery.map((exercise) => exercise.mode).toSet().length,
        greaterThan(1),
        reason: '${target.id}: добор не должен состоять из одного теста',
      );
      expect(
        generator.build(
          plan: plan,
          ctx: context,
          sessionId: 2,
          previousCounts: {target.id: 3},
        ),
        hasLength(2),
        reason: '${target.id}: прошлые задания входят в лимит занятия',
      );
      expect(
        generator.build(
          plan: plan,
          ctx: context,
          sessionId: 2,
          previousCounts: {target.id: 5},
        ),
        isEmpty,
        reason: '${target.id}: исчерпанная буква не строится снова',
      );
    }
  });

  test('наблюдавшийся на Алиф сценарий не заполняет занятие', () async {
    final at = DateTime(2026, 9, 12);
    await repository.recordAll([
      AtomIntroduced(atomId: 'concept.letter', sessionId: 1, at: at),
      for (final id in ['ba.isolated', 'ta.isolated', 'tha.isolated'])
        KnowledgeConfirmed(atomId: id, sessionId: 1, at: at),
      AtomIntroduced(atomId: 'alif.isolated', sessionId: 1, at: at),
      for (final mode in const [
        ExerciseMode.trace,
        ExerciseMode.traceFromMemory,
        ExerciseMode.soundToLetter,
      ])
        ProgressEvent(
          atomId: 'alif.isolated',
          sessionId: 1,
          at: at,
          mode: mode,
          correct: true,
          attempt: 1,
          fastEnough: true,
        ),
      ProgressEvent(
        atomId: 'alif.isolated',
        sessionId: 1,
        at: at,
        mode: ExerciseMode.soundToLetter,
        correct: false,
        attempt: 1,
        fastEnough: true,
      ),
    ]);

    final context = CurriculumContext(
      progress: await repository.progress(),
      formsByLetter: curriculum.formsByLetter,
    );
    expect(context.progress['alif.isolated']!.state, AtomState.learning);
    final planner = LessonPlanner(curriculum: curriculum, rules: rules);
    final initial = planner.plan(
      ctx: context,
      sessionId: 2,
      sessionsWithoutNew: 0,
    );
    expect(initial.reviewCounts, {'alif.isolated': 3});
    final cappedExercises =
        ExerciseGenerator(curriculum: curriculum, rules: rules).build(
          plan: initial,
          ctx: context,
          sessionId: 2,
          previousCounts: const {'alif.isolated': 3},
        );
    expect(cappedExercises, hasLength(2));
    expect(
      planner
          .plan(
            ctx: context,
            sessionId: 2,
            sessionsWithoutNew: 0,
            previousCounts: const {'alif.isolated': 3},
          )
          .reviewCounts,
      {'alif.isolated': 2},
      reason: 'лимит учитывает уже пройденный короткий блок',
    );
    final afterLimit = planner.plan(
      ctx: context,
      sessionId: 2,
      sessionsWithoutNew: 0,
      previousCounts: const {'alif.isolated': 5},
    );
    expect(afterLimit.reviewCounts, isNot(contains('alif.isolated')));
    expect(afterLimit.reviewAtoms, isNot(contains('alif.isolated')));

    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      rules: rules,
      plan: initial,
      continuePlanning: true,
      shapeLoader: (_) async =>
          throw UnsupportedError('Холст здесь не проверяется'),
    );
    addTearDown(controller.onClose);
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) ready.complete();
    });
    controller.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();

    final asked = <({String id, ExerciseMode mode})>[];
    var steps = 0;
    while (controller.stage.value != LessonStage.finished) {
      expect(steps++, lessThan(rules.tasksPerSession + 10));
      if (controller.stage.value == LessonStage.intro) {
        await controller.nextIntro();
        continue;
      }
      while (controller.card.value != null) {
        await controller.dismissCard();
      }
      final exercise = controller.current!;
      asked.add((id: exercise.atom.id, mode: exercise.mode));
      await controller.answerCorrectly(advance: true);
    }

    final alif = asked.where((item) => item.id == 'alif.isolated').toList();
    expect(alif.length, lessThanOrEqualTo(5));
    expect(alif.map((item) => item.mode).toSet().length, greaterThan(1));
    expect(asked.map((item) => item.id).toSet().length, greaterThan(1));
    final events = (await database.readAll())
        .whereType<ProgressEvent>()
        .where((event) => event.atomId == 'alif.isolated')
        .toList();
    await repository.recompute();
    expect(
      (await repository.progress())['alif.isolated']!.state.index,
      greaterThanOrEqualTo(AtomState.known.index),
      reason:
          'asked=$alif; events=${events.map((event) => '${event.sessionId}:'
              '${event.mode}:${event.correct}:${event.attempt}').toList()}',
    );
  });
}
