import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Выход из занятия не разрешает новый материал. Проверяем все блоки
/// реального курса, недостающие обязательные режимы и продвижение по
/// знаниям без отметки о завершении или сохранённой очереди заданий.
void main() {
  final course = CurriculumLoader.merge([
    for (final stage in ['stage1', 'stage2'])
      CurriculumLoader.parse(
        File('assets/curriculum/$stage.json').readAsStringSync(),
      ),
  ]);
  const fold = ProgressFold();
  const rules = LearningRules();
  final at = DateTime(2026, 9, 10);
  final board = TopicBoard(course);
  final planner = LessonPlanner(curriculum: course);

  CurriculumContext context(Map<String, AtomProgress> progress) =>
      CurriculumContext(
        progress: progress,
        formsByLetter: course.formsByLetter,
      );

  LessonPlan plan(Map<String, AtomProgress> progress, {int session = 2}) =>
      planner.plan(
        ctx: context(progress),
        sessionId: session,
        // Даже многократный выход не должен включить обход практики
        // через гарантию темпа после двух заходов без нового материала.
        sessionsWithoutNew: 10,
      );

  AtomIntroduced introduce(String id) =>
      AtomIntroduced(atomId: id, sessionId: 1, at: at);

  ProgressEvent answer(String id, ExerciseMode mode, {bool correct = true}) =>
      ProgressEvent(
        atomId: id,
        sessionId: 1,
        at: at,
        mode: mode,
        correct: correct,
        attempt: 1,
        fastEnough: true,
      );

  Map<String, AtomProgress> confirmed(Iterable<Topic> topics) => fold.fold([
    for (final id in topics.expand((t) => t.counterOf).toSet())
      course.nodes.firstWhere((n) => n.atom.id == id).atom.kind ==
              AtomKind.concept
          ? introduce(id)
          : KnowledgeConfirmed(atomId: id, sessionId: 1, at: at),
  ]);

  test(
    'выход после объяснения или одного ответа сохраняет текущий материал',
    () {
      var progress = <String, AtomProgress>{};
      final visited = <String>{};
      while (true) {
        final initial = plan(progress);
        if (initial.topicId == null) break;
        expect(
          visited.add(initial.topicId!),
          isTrue,
          reason: 'нет продвижения',
        );
        final topic = course.topics.firstWhere((t) => t.id == initial.topicId);
        final drill = initial.newAtoms.firstWhere(
          (a) => a.kind != AtomKind.concept,
        );

        for (final shown in [1, initial.newAtoms.length]) {
          final introduced = fold.foldOnto(progress, [
            for (final atom in initial.newAtoms.take(shown)) introduce(atom.id),
          ]);
          expect(
            plan(introduced).topicId,
            topic.id,
            reason: '${topic.id}: карточки',
          );
        }
        final partial = fold.foldOnto(progress, [
          for (final atom in initial.newAtoms) introduce(atom.id),
          answer(drill.id, ExerciseMode.soundToLetter),
        ]);
        final continued = plan(partial);
        expect(continued.topicId, topic.id, reason: '${topic.id}: один ответ');
        expect(continued.newAtoms, isEmpty);
        expect(continued.isFocusedReview, isTrue);
        expect(continued.reviewAtoms, isNotEmpty);
        expect(continued.reviewAtoms.every(topic.counterOf.contains), isTrue);
        final exercises = ExerciseGenerator(
          curriculum: course,
          random: Random(1),
        ).build(plan: continued, ctx: context(partial), sessionId: 2);
        expect(
          exercises.map((e) => e.atom.id).toSet(),
          continued.reviewAtoms.toSet(),
        );
        expect(exercises.length, lessThanOrEqualTo(rules.focusedReviewTasks));
        progress = {
          ...progress,
          ...confirmed([topic]),
        };
      }
      expect(visited.length, course.topics.length);
      expect(board.statuses(context(progress)).every((s) => s.isDone), isTrue);
    },
  );

  test(
    'известная буква без одного обязательного режима остаётся в практике',
    () {
      final first = course.topics.first;
      final base = course.nodes
          .firstWhere((n) => n.atom.id == 'ba.isolated')
          .atom;
      for (final missing in rules.requiredPracticeModes(base)) {
        final progress = confirmed([first]);
        final practiced = rules.requiredPracticeModes(base).difference({
          missing,
        });
        final log = [
          introduce(base.id),
          for (final mode in [...practiced, practiced.first])
            answer(base.id, mode),
        ];
        progress[base.id] = fold.fold(log)[base.id]!;
        expect(progress[base.id]!.state, AtomState.known);
        expect(board.statuses(context(progress)).first.isDone, isFalse);
        final continued = plan(progress);
        expect(continued.topicId, first.id, reason: 'пропущен $missing');
        expect(continued.reviewAtoms, [base.id]);
        expect(continued.reviewCounts, {base.id: 1});
        final exercises = ExerciseGenerator(
          curriculum: course,
        ).build(plan: continued, ctx: context(progress), sessionId: 2);
        expect(exercises, hasLength(1));
        expect(exercises.single.mode, missing);

        // Последнее нужное умение, а не конец сессии, разрешает формы.
        final ready = fold.foldOnto(progress, [answer(base.id, missing)]);
        expect(plan(ready).topicId, 'm.forms');
      }
    },
  );

  test('первого верного прохождения достаточно даже без быстрых ответов', () {
    final initial = plan({});
    final shown = fold.fold([
      for (final atom in initial.newAtoms) introduce(atom.id),
    ]);
    final exercises = ExerciseGenerator(
      curriculum: course,
      random: Random(5),
    ).build(plan: initial, ctx: context(shown), sessionId: 1);
    final progress = fold.foldOnto(shown, [
      for (final exercise in exercises)
        ProgressEvent(
          atomId: exercise.atom.id,
          sessionId: 1,
          at: at,
          mode: exercise.mode,
          correct: true,
          attempt: 1,
          fastEnough: false,
        ),
    ]);
    expect(board.statuses(context(progress)).first.isDone, isTrue);
    expect(plan(progress).topicId, 'm.forms');
  });

  test('одна недоученная буква даёт короткую практику, а не всю тему', () {
    final progress = confirmed([course.topics.first]);
    progress['ba.isolated'] = const AtomProgress(
      state: AtomState.learning,
      cleanStreak: 1,
      modesInStreak: {ExerciseMode.trace},
      hadActiveSuccess: true,
      successfulModes: {
        ExerciseMode.trace,
        ExerciseMode.traceFromMemory,
        ExerciseMode.sayName,
      },
    );
    final focused = plan(progress);
    expect(focused.reviewAtoms, ['ba.isolated']);
    final exercises = ExerciseGenerator(
      curriculum: course,
      random: Random(7),
    ).build(plan: focused, ctx: context(progress), sessionId: 2);
    expect(exercises, hasLength(2));
    final ready = fold.foldOnto(progress, [
      for (final e in exercises) answer(e.atom.id, e.mode),
    ]);
    expect(plan(ready).topicId, 'm.forms');
    final manual = board.planFor(course.topics.first, context(progress));
    expect(manual.isFocusedReview, isFalse);
    expect(manual.reviewAtoms.toSet(), course.topics.first.counterOf.toSet());
  });

  test('новое правило не вытесняет непроверенные сочетания', () {
    final progress = fold.foldOnto(confirmed(course.topics.take(2)), [
      introduce('concept.join'),
    ]);
    expect(plan(progress).topicId, 'm.join');
    expect(plan(progress).newAtoms.map((a) => a.id), [
      'syl.ba_ta',
      'syl.ta_ba',
    ]);
  });

  test('ошибка возвращает закрепление, но не закрывает уже открытые формы', () {
    final progress = fold.foldOnto(confirmed(course.topics.take(2)), [
      answer('ba.isolated', ExerciseMode.trace, correct: false),
    ]);
    expect(plan(progress).topicId, 'm.first');
    expect(board.statuses(context(progress))[1].canPractice, isTrue);
  });

  test('пауза после серии ошибок не отменяется приоритетом закрепления', () {
    final progress = fold.foldOnto(confirmed([course.topics.first]), [
      for (var i = 0; i < rules.errorsBeforeDefer; i++)
        answer('ba.isolated', ExerciseMode.trace, correct: false),
    ]);
    final paused = plan(progress);
    expect(paused.reviewAtoms, isNot(contains('ba.isolated')));
    expect(paused.spacedReview, isNot(contains('ba.isolated')));
    expect(plan(progress, session: 1 + rules.deferSessions).topicId, 'm.first');
  });
}
