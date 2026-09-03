import 'dart:math';

import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Обводка — задание на воспроизведение, а не на узнавание, и потому
/// обязательная часть работы над буквой, а не запасной вариант.
/// Порядок всегда один: сначала по контуру, потом по памяти.
Atom letter(String id, {String? tracing}) => Atom(
  id: '$id.isolated',
  kind: AtomKind.letterForm,
  display: id,
  letterId: id,
  form: LetterForm.isolated,
  confusableWith: const [],
  tracing: tracing,
);

final ba = letter('ba', tracing: 'ba_base');
final ta = letter('ta', tracing: 'ta_base');

/// Буква без осевого SVG — как все соединённые формы сейчас.
final nun = letter('nun');

final siin = letter('siin');
final miim = letter('miim');

final curriculum = Curriculum(
  topics: const [],
  nodes: [
    for (final a in [ba, ta, nun, siin, miim])
      CurriculumNode(atom: a, requirement: const Always()),
  ],
);

CurriculumContext ctxOf(Map<String, AtomProgress> progress) =>
    CurriculumContext(progress: progress, formsByLetter: const {});

ExerciseGenerator gen() =>
    ExerciseGenerator(curriculum: curriculum, random: Random(7));

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
  final others = {
    for (final a in [ta, siin, miim]) a.id: introduced,
  };

  List<ExerciseMode> modesOf(List<Exercise> ex, Atom atom) => [
    for (final e in ex.where((e) => e.atom == atom)) e.mode,
  ];

  test('новая буква пишется: сначала по контуру, потом по памяти', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf(others),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(modes.first, ExerciseMode.trace);
    expect(modes.last, ExerciseMode.traceFromMemory);
    // Между письмом остаётся узнавание: урок не сводится к рисованию.
    expect(modes.where((m) => m.isTracing), hasLength(2));
  });

  test('по памяти не просят раньше, чем букву вели рукой', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf(others),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(
      modes.indexOf(ExerciseMode.trace),
      lessThan(modes.indexOf(ExerciseMode.traceFromMemory)),
    );
  });

  test('уже написанная буква сразу просится по памяти', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf({
        ...others,
        ba.id: const AtomProgress(
          state: AtomState.learning,
          hadActiveSuccess: true,
        ),
      }),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(modes, isNot(contains(ExerciseMode.trace)));
    expect(modes.last, ExerciseMode.traceFromMemory);
  });

  test('буква без SVG обводкой не спрашивается', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [nun]),
      ctx: ctxOf(others),
      sessionId: 1,
    );

    expect(ex, isNotEmpty);
    expect(ex.every((e) => !e.mode.isTracing), isTrue);
  });

  test('в повторении обводка даётся один раз за урок', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [siin], review: [ba.id]),
      ctx: ctxOf({...others, ba.id: introduced}),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(modes.where((m) => m.isTracing), [ExerciseMode.trace]);
  });

  test('освоенная буква возвращается письмом по памяти', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [siin], review: [ba.id]),
      ctx: ctxOf({
        ...others,
        ba.id: const AtomProgress(
          state: AtomState.known,
          hadActiveSuccess: true,
        ),
      }),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(modes.where((m) => m.isTracing), [ExerciseMode.traceFromMemory]);
  });
}
