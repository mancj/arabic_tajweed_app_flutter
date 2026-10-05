// Повторение форм в огласовках должно занимать ровно два места всей сессии,
// сохранять письмо, голос и звуковые сборки и не возвращать другие задания
// алфавита. Проверяем все темы огласовок, ротацию всех 28 букв, короткую
// версию для несоединяющихся букв и отсутствие этой добавки после огласовок.
// Ошибка исправляется в том же задании и не создаёт третью сборку.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/form_sequence_evaluation.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  final knownAt = DateTime(2026, 9, 20);
  CurriculumContext before(Topic target) => CurriculumContext(
    progress: {
      for (final topic in curriculum.topics.takeWhile((t) => t.id != target.id))
        for (final id in topic.counterOf)
          id: AtomProgress(
            state: byId[id]!.kind == AtomKind.concept
                ? AtomState.introduced
                : AtomState.mastered,
            successfulModes: ExerciseMode.values.toSet(),
            cleanStreak: 3,
            knownAt: knownAt,
            lastSeenSession: 1,
          ),
    },
    formsByLetter: curriculum.formsByLetter,
  );
  final full = before(curriculum.topics.firstWhere((t) => t.id == 'm.join'));
  final syllables = byId.values
      .where((atom) => atom.id.startsWith('vowel.') && full.isKnown(atom.id))
      .take(20)
      .toList();
  LessonPlan review(List<Atom> atoms) => LessonPlan(
    template: LessonTemplate.review,
    newAtoms: const [],
    reviewAtoms: atoms.map((atom) => atom.id).toList(),
    reviewCounts: {for (final atom in atoms) atom.id: 1},
    reason: 'смешанное повторение огласовок',
  );

  test('все новые темы получают две сборки без потери практики', () {
    for (final topic in curriculum.topics.where(
      (t) => t.id == 'm.haraka.signs' || t.id.startsWith('m.haraka.group'),
    )) {
      final ctx = before(topic);
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
      for (var seed = 0; seed < 10; seed++) {
        final tasks = ExerciseGenerator(
          curriculum: curriculum,
          random: Random(seed),
        ).build(plan: plan, ctx: ctx, sessionId: 100);
        final forms = tasks.where((task) => task.isFormMaintenance).toList();
        expect(
          forms,
          hasLength(2),
          reason:
              '${topic.id}, seed $seed: '
              '${tasks.map((t) => '${t.atom.id}/${t.mode.name}/${t.isRequired}').join(', ')}',
        );
        expect(forms.map((task) => task.atom.letterId).toSet(), hasLength(2));
        expect(tasks.length, lessThanOrEqualTo(20));
        expect(
          tasks.where((task) => task.atom.kind == AtomKind.letterForm),
          everyElement(predicate<Exercise>((task) => task.isFormMaintenance)),
        );
        expect(
          tasks.where((task) => task.mode.isPronunciation).length,
          lessThanOrEqualTo(max(1, tasks.length ~/ 4)),
        );
        for (final atom in plan.newAtoms.where(
          (a) => a.kind != AtomKind.concept,
        )) {
          final modes = tasks
              .where((task) => task.atom == atom)
              .map((task) => task.mode)
              .toSet();
          expect(
            modes,
            containsAll(const LearningRules().requiredPracticeModes(atom)),
            reason: atom.id,
          );
        }
        if (topic.id.startsWith('m.haraka.group')) {
          final sequences = tasks.where((task) => task.mode.isHarakaSequence);
          expect(sequences.length, lessThanOrEqualTo(3));
        }
      }
    }
  });

  test(
    'первая буква давно не встречалась, вторая исправляет слабое знание',
    () {
      final ctx = CurriculumContext(
        progress: {
          ...full.progress,
          for (final atom in curriculum.baseLetters)
            for (final id in curriculum.formsByLetter[atom.letterId]!)
              id: full.progress[id]!.copyWith(lastSeenSession: 50),
          for (final id in curriculum.formsByLetter['alif']!)
            id: full.progress[id]!.copyWith(lastSeenSession: 1),
          'dal.finalForm': full.progress['dal.finalForm']!.copyWith(
            state: AtomState.learning,
            lastSeenSession: 90,
          ),
        },
        formsByLetter: curriculum.formsByLetter,
      );
      final tasks = ExerciseGenerator(
        curriculum: curriculum,
      ).build(plan: review(syllables), ctx: ctx, sessionId: 100);
      expect(
        tasks
            .where((task) => task.isFormMaintenance)
            .map((task) => task.atom.letterId)
            .toSet(),
        {'alif', 'dal'},
      );
      expect(tasks, hasLength(20));
    },
  );

  test('две сборки разделяют общий предел при доборе занятия', () {
    final first = ExerciseGenerator(curriculum: curriculum).build(
      plan: review(syllables.take(8).toList()),
      ctx: full,
      sessionId: 100,
      taskLimit: 8,
    );
    final letters = first
        .where((task) => task.isFormMaintenance)
        .map((task) => task.atom.letterId!)
        .toSet();
    expect(letters, hasLength(2));
    final next = ExerciseGenerator(curriculum: curriculum).build(
      plan: review(syllables.skip(8).toList()),
      ctx: full,
      sessionId: 100,
      taskLimit: 12,
      previousTaskCount: first.length,
      previousFormSequences: letters,
      previousPronunciations: first
          .where((task) => task.mode.isPronunciation)
          .map((task) => task.atom.id)
          .toSet(),
    );
    expect(next.where((task) => task.isFormMaintenance), isEmpty);
    expect(first.length + next.length, 20);
  });

  test('ротация доступна всему алфавиту, включая шесть двухформенных букв', () {
    var ctx = full;
    final seen = <String>{};
    for (var session = 100; session < 114; session++) {
      final tasks = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(session),
      ).build(plan: review(syllables), ctx: ctx, sessionId: session);
      final forms = tasks.where((task) => task.isFormMaintenance).toList();
      expect(forms, hasLength(2));
      final changes = <String, AtomProgress>{};
      for (final task in forms) {
        expect(seen.add(task.atom.letterId!), isTrue);
        expect(
          task.resultAtoms.length,
          const {
                'alif',
                'dal',
                'dhal',
                'ra',
                'zay',
                'waw',
              }.contains(task.atom.letterId)
              ? 2
              : 4,
        );
        final placed = task.options.sortedBy((atom) => atom.form!.index);
        expect(
          FormSequenceEvaluation.evaluate(
            options: task.options,
            placed: placed,
          ).correct,
          isTrue,
        );
        for (final atom in task.resultAtoms) {
          changes[atom.id] = ctx.progress[atom.id]!.copyWith(
            lastSeenSession: session,
          );
        }
      }
      ctx = CurriculumContext(
        progress: {...ctx.progress, ...changes},
        formsByLetter: curriculum.formsByLetter,
      );
    }
    expect(seen, curriculum.baseLetters.map((atom) => atom.letterId).toSet());
  });

  test('неизвестные и отложенные формы не попадают в сборки', () {
    final ctx = CurriculumContext(
      progress: {
        ...full.progress,
        'ba.medial': const AtomProgress(),
        for (final id in curriculum.formsByLetter['alif']!)
          id: full.progress[id]!.copyWith(deferredAtSession: 99),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    final tasks = ExerciseGenerator(
      curriculum: curriculum,
    ).build(plan: review(syllables), ctx: ctx, sessionId: 100);
    expect(
      tasks
          .where((task) => task.isFormMaintenance)
          .map((task) => task.atom.letterId),
      isNot(anyElement(isIn(['ba', 'alif']))),
    );
  });

  test('сборки не вытесняют полностью обязательный короткий блок', () {
    final topic = curriculum.topics.firstWhere((t) => t.id == 'm.haraka.signs');
    final ctx = before(topic);
    final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
    final tasks = ExerciseGenerator(
      curriculum: curriculum,
    ).build(plan: plan, ctx: ctx, sessionId: 100, taskLimit: 12);
    expect(tasks, hasLength(12));
    expect(tasks.where((task) => task.isFormMaintenance), isEmpty);
    for (final atom in plan.newAtoms) {
      expect(
        tasks.where((task) => task.atom == atom).map((task) => task.mode),
        containsAll(const LearningRules().requiredPracticeModes(atom)),
      );
    }
  });

  test('в алфавите и словах добавка отсутствует', () {
    for (final topic in curriculum.topics.where((t) => t.stage != 2)) {
      final ctx = before(topic);
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
      final tasks = ExerciseGenerator(
        curriculum: curriculum,
      ).build(plan: plan, ctx: ctx, sessionId: 100);
      expect(
        tasks.where((task) => task.isFormMaintenance),
        isEmpty,
        reason: topic.id,
      );
    }
    expect(
      const LearningRules()
          .copyWith(requirePronunciation: false)
          .letterFormReviewsPerHarakaSession,
      2,
    );
  });

  test('ошибка в сборке не увеличивает её долю и честно оценивает формы', () {
    final tasks = ExerciseGenerator(
      curriculum: curriculum,
    ).build(plan: review(syllables), ctx: full, sessionId: 100);
    final session = LessonSession(exercises: tasks, sessionId: 100);
    var forms = 0;
    while (!session.isFinished) {
      final task = session.current!;
      if (task.isFormMaintenance) {
        forms++;
        final order = task.options.sortedBy((atom) => atom.form!.index);
        final wrong = [...order]..swap(0, 1);
        final evaluation = FormSequenceEvaluation.evaluate(
          options: task.options,
          placed: wrong,
        );
        expect(evaluation.correct, isFalse);
        expect(evaluation.slotResults.take(2), [false, false]);
        expect(
          session.answer(
            task,
            Exercise.directMiss,
            atomResults: evaluation.atomResults,
          ),
          AnswerOutcome.wrong,
        );
        expect(session.requeuedCount, 0);
      }
      session.answer(task, task.answerIndex);
    }
    expect(forms, 2);
    expect(session.total, 20);
  });
}
