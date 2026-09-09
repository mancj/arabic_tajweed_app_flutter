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
final baFinal = Atom(
  id: 'ba.finalForm',
  kind: AtomKind.letterForm,
  display: 'ـب',
  letterId: 'ba',
  form: LetterForm.finalForm,
);
final baInitial = Atom(
  id: 'ba.initial',
  kind: AtomKind.letterForm,
  display: 'بـ',
  letterId: 'ba',
  form: LetterForm.initial,
);
final concept = const Atom(
  id: 'concept.dots',
  kind: AtomKind.concept,
  display: 'Точки',
);

final curriculum = Curriculum(
  topics: const [],
  nodes: [
    for (final a in [ba, ta, tha, siin, miim, baFinal, baInitial, concept])
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
  List<String> spaced = const [],
}) => LessonPlan(
  template: LessonTemplate.newLetter,
  newAtoms: newAtoms,
  reviewAtoms: review,
  spacedReview: spaced,
  reason: 'тест',
);

void main() {
  const introduced = AtomProgress(state: AtomState.introduced);

  test('каждую отдельную букву просят назвать ровно раз за урок', () {
    for (var seed = 0; seed < 30; seed++) {
      final ex = ExerciseGenerator(curriculum: curriculum, random: Random(seed))
          .build(
            plan: planOf(
              newAtoms: [ba, baFinal],
              review: [ta.id],
              spaced: [tha.id],
            ),
            ctx: ctxOf({
              for (final a in [ta, tha, siin, miim]) a.id: introduced,
            }),
            sessionId: 1,
          );
      final spoken = ex.where((e) => e.mode == ExerciseMode.sayName).toList();

      // Имя одно на все формы — спрашивается только у отдельной.
      expect(spoken.map((e) => e.atom.form), everyElement(LetterForm.isolated));
      // Каждая отдельная буква из плана получает ровно одно задание.
      expect(spoken.map((e) => e.atom.letterId).toSet(), {'ba', 'ta', 'tha'});
      expect(spoken, hasLength(3));
      // Новую букву сначала узнают, потом просят назвать.
      final firstBa = ex.indexWhere((e) => e.atom == ba);
      expect(ex[firstBa].mode, isNot(ExerciseMode.sayName));
    }
  });

  test('одна буква не растягивается на двенадцать заданий', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf({
        for (final a in [ta, tha, siin, miim]) a.id: introduced,
      }),
      sessionId: 1,
    );
    // Добивать урок до двадцати одной и той же буквой — не тренировка:
    // у одного атома потолок пять заданий.
    expect(ex, hasLength(5));
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
    expect(ex, hasLength(20));
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
    // «Назвать вслух» — задание без вариантов, уровня у него нет:
    // смотрим только на задания с выбором.
    final choice = ex.where((e) => e.isChoice).toList();
    expect(choice, isNotEmpty);
    expect(choice.every((e) => e.level == DistractorLevel.minimalPair), isTrue);
    // Режим тот же, на слух: минимальная пара — уровень вариантов, а не
    // отдельное задание.
    expect(choice.every((e) => e.mode == ExerciseMode.soundToLetter), isTrue);
    expect(
      choice.expand((e) => e.options).map((a) => a.id),
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
    final choice = ex.where((e) => e.isChoice).toList();
    expect(choice, isNotEmpty);
    expect(choice.every((e) => e.level == DistractorLevel.mixed), isTrue);
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
    final choice = ex.where((e) => e.isChoice).toList();
    expect(choice, isNotEmpty);
    for (final e in choice) {
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
    expect(ex.length, lessThanOrEqualTo(20));
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

  /// Задания с выбором строятся без русского имени: на слух — буквы в той
  /// же форме, о позиции — формы той же буквы. См. SPEC.md §4.
  group('выбор без имени буквы', () {
    final ctx = ctxOf({
      for (final a in [ba, ta, tha, siin, miim, baFinal, baInitial])
        a.id: introduced,
    });

    List<Exercise> many() => [
      for (var seed = 0; seed < 20; seed++)
        ...ExerciseGenerator(
          curriculum: curriculum,
          random: Random(seed),
        ).build(
          plan: planOf(review: [ba.id, ta.id, baFinal.id]),
          ctx: ctx,
          sessionId: 1,
        ),
    ].where((e) => e.isChoice).toList();

    test('на слух варианты стоят в той же форме, что ответ', () {
      final byEar = many().where((e) => e.mode == ExerciseMode.soundToLetter);
      expect(byEar, isNotEmpty);
      for (final e in byEar) {
        expect(e.options.map((o) => o.form).toSet(), {e.atom.form});
      }
    });

    test('вопрос о позиции предлагает формы той же буквы', () {
      final byPosition = many().where(
        (e) => e.mode == ExerciseMode.positionToForm,
      );
      expect(byPosition, isNotEmpty, reason: 'у ба введены три формы');
      for (final e in byPosition) {
        final prompt = e.prompt;
        expect(prompt, isNotNull, reason: 'в вопросе показана форма буквы');
        expect(prompt!.letterId, e.atom.letterId);
        expect(prompt.id, isNot(e.atom.id), reason: 'иначе ответ виден');
        if (e.atom.form != LetterForm.isolated) {
          expect(
            prompt.form,
            LetterForm.isolated,
            reason: 'в вопросе отдельная форма, если спрашивают не её',
          );
        }
        expect(e.options.map((o) => o.letterId).toSet(), {e.atom.letterId});
        expect(e.options.map((o) => o.id).toSet().length, e.options.length);
        expect(
          e.options.map((o) => o.id),
          isNot(contains(prompt.id)),
          reason: 'показанную форму выбирать нет смысла',
        );
        expect(e.options.length, greaterThanOrEqualTo(2));
      }
    });

    test('старые режимы с именем буквы не строятся', () {
      const legacy = {
        ExerciseMode.formToName,
        ExerciseMode.nameToForm,
        ExerciseMode.letterToSound,
        ExerciseMode.formToPosition,
        ExerciseMode.distinguishDots,
      };
      expect(many().map((e) => e.mode).where(legacy.contains), isEmpty);
    });
  });
}
