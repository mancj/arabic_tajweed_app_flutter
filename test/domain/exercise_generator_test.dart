import 'dart:math';

import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

Atom letter(String id, {List<String> confusable = const []}) => Atom(
  id: '$id.isolated',
  kind: AtomKind.letterForm,
  display: id,
  letterId: id,
  form: LetterForm.isolated,
  confusableWith: confusable,
);

final ba = letter('ba', confusable: ['ta', 'tha']);
final ta = letter('ta', confusable: ['ba', 'tha']);
final tha = letter('tha', confusable: ['ba', 'ta']);
final siin = letter('siin');
final miim = letter('miim');
final concept = const Atom(
  id: 'concept.dots',
  kind: AtomKind.concept,
  display: 'Точки',
);

final curriculum = Curriculum(
  topics: const [],
  nodes: [
    for (final a in [ba, ta, tha, siin, miim, concept])
      CurriculumNode(atom: a, requirement: const Always()),
  ],
);

CurriculumContext ctxOf(Map<String, AtomProgress> progress) =>
    CurriculumContext(progress: progress, formsByLetter: const {});

ExerciseGenerator gen() =>
    ExerciseGenerator(curriculum: curriculum, random: Random(42));

LessonPlan planOf({
  List<Atom> newAtoms = const [],
  List<String> review = const [],
}) => LessonPlan(
  template: LessonTemplate.newLetter,
  newAtoms: newAtoms,
  reviewAtoms: review,
  reason: 'тест',
);

void main() {
  const introduced = AtomProgress(state: AtomState.introduced);

  test('одна буква не растягивается на двенадцать заданий', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf({
        for (final a in [ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    // Добивать урок до двенадцати одной и той же буквой — не тренировка.
    expect(ex, hasLength(3));
    expect(ex.every((e) => e.atom == ba), isTrue);
  });

  test('четырёх атомов хватает на полную сессию', () {
    final ex = gen().build(
      plan: planOf(review: [ba.id, ta.id, tha.id, siin.id]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex, hasLength(12));
  });

  test('дистракторы берутся только из введённых атомов', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf({ta.id: introduced, tha.id: introduced}),
      sessionId: 1,
    );
    final used = ex.expand((e) => e.options).map((a) => a.id).toSet();
    expect(used, isNot(contains(siin.id)));
    expect(used, isNot(contains(miim.id)));
  });

  test('новый атом получает далёкие дистракторы, а не минимальную пару', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf({
        for (final a in [ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex.map((e) => e.level), everyElement(DistractorLevel.distant));
  });

  test('перед переходом в known даётся минимальная пара', () {
    final ex = gen().build(
      plan: planOf(review: [ba.id]),
      ctx: ctxOf({
        ba.id: const AtomProgress(state: AtomState.learning, cleanStreak: 2),
        ta.id: introduced,
        tha.id: introduced,
        siin.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex.every((e) => e.level == DistractorLevel.minimalPair), isTrue);
    expect(ex.every((e) => e.mode == ExerciseMode.distinguishDots), isTrue);
    expect(
      ex.expand((e) => e.options).map((a) => a.id),
      isNot(contains(siin.id)),
    );
  });

  test('без введённой пары минимальная пара откатывается в смешанную', () {
    final ex = gen().build(
      plan: planOf(review: [ba.id]),
      ctx: ctxOf({
        ba.id: const AtomProgress(state: AtomState.learning, cleanStreak: 2),
        siin.id: introduced,
        miim.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex.every((e) => e.level == DistractorLevel.mixed), isTrue);
  });

  test('атом после паузы возвращается на далёкие дистракторы', () {
    final ex = gen().build(
      plan: planOf(review: [ba.id]),
      ctx: ctxOf({
        ba.id: const AtomProgress(
          state: AtomState.learning,
          cleanStreak: 2,
          deferCount: 1,
          deferredAtSession: 1,
        ),
        ta.id: introduced,
        tha.id: introduced,
        siin.id: introduced,
        miim.id: introduced,
      }),
      sessionId: 9,
    );
    expect(ex.every((e) => e.level == DistractorLevel.distant), isTrue);
  });

  test('понятия не превращаются в задания с выбором', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [concept]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha]) a.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex, isEmpty);
  });

  test('верный ответ всегда лежит по answerIndex', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba], review: [ta.id, tha.id]),
      ctx: ctxOf({
        for (final a in [ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex, isNotEmpty);
    for (final e in ex) {
      expect(e.options[e.answerIndex], e.atom);
    }
  });

  test('в сессии участвуют все атомы плана, а не только первый', () {
    final ex = gen().build(
      plan: planOf(review: [ba.id, ta.id, tha.id]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex.map((e) => e.atom.id).toSet(), {ba.id, ta.id, tha.id});
  });

  test('одну и ту же букву не спрашивают подряд', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba], review: [ta.id, tha.id, siin.id]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );

    final ids = ex.map((e) => e.atom.id).toList();
    for (var i = 1; i < ids.length; i++) {
      expect(
        ids[i],
        isNot(ids[i - 1]),
        reason: 'подряд одна буква на позиции $i: $ids',
      );
    }
  });

  test('новый атом встречается чаще старых', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba], review: [ta.id, tha.id, siin.id]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );

    final counts = <String, int>{};
    for (final e in ex) {
      counts[e.atom.id] = (counts[e.atom.id] ?? 0) + 1;
    }
    expect(counts[ba.id], greaterThanOrEqualTo(counts[ta.id]!));
  });

  test('сессия не длиннее лимита заданий', () {
    final ex = gen().build(
      plan: planOf(review: [for (var i = 0; i < 40; i++) ba.id]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    expect(ex.length, lessThanOrEqualTo(12));
  });

  test('в задании всегда три варианта ответа', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba], review: [ta.id, tha.id, siin.id]),
      ctx: ctxOf({
        for (final a in [ba, ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );

    final choices = ex.where((e) => e.isChoice);
    expect(choices, isNotEmpty);
    for (final e in choices) {
      expect(e.options, hasLength(3));
      expect(e.options.toSet(), hasLength(3), reason: 'без повторов');
    }
  });
}
