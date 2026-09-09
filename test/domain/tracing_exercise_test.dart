import 'dart:math';

import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
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
  final others = {
    for (final a in [ta, siin, miim]) a.id: introduced,
  };

  List<ExerciseMode> modesOf(List<Exercise> ex, Atom atom) => [
    for (final e in ex.where((e) => e.atom == atom)) e.mode,
  ];

  bool isActive(ExerciseMode mode) =>
      mode.isTracing || mode == ExerciseMode.sayName;

  /// Активные задания и узнавание чередуются строго через одно.
  void expectAlternating(
    List<ExerciseMode> modes, {
    required bool activeFirst,
  }) {
    for (var i = 0; i < modes.length; i++) {
      expect(
        isActive(modes[i]),
        activeFirst ? i.isEven : i.isOdd,
        reason: 'слот $i в $modes',
      );
    }
  }

  test('новая буква пишется через задание: контур, потом по памяти', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [ba]),
      ctx: ctxOf(others),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(modes.first, ExerciseMode.trace);
    expect(modes, contains(ExerciseMode.traceFromMemory));
    // Активное задание — рука или голос — через одно с узнаванием:
    // письмо занимает половину слотов, а не один, но урок не сводится
    // к рисованию.
    expectAlternating(modes, activeFirst: true);
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

  // Успех в прошлом уроке не должен убирать обязательную обводку
  // при повторном изучении базовой формы.
  test('повторное изучение сохраняет оба вида письма и голос', () {
    final ex = gen().build(
      plan: planOf(review: [ba.id]),
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
    expect(modes.first, ExerciseMode.trace);
    expect(modes, contains(ExerciseMode.traceFromMemory));
    expect(modes.last, ExerciseMode.sayName);
    expectAlternating(modes, activeFirst: true);
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
      plan: planOf(newAtoms: [siin], spaced: [ba.id]),
      ctx: ctxOf({...others, ba.id: introduced}),
      sessionId: 1,
    );

    final modes = modesOf(ex, ba);
    expect(modes.where((m) => m.isTracing), [ExerciseMode.trace]);
  });

  test('освоенная буква возвращается письмом по памяти', () {
    final ex = gen().build(
      plan: planOf(newAtoms: [siin], spaced: [ba.id]),
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
    expect(modes, isNot(contains(ExerciseMode.trace)));
    expect(modes, contains(ExerciseMode.traceFromMemory));
    expect(modes, hasLength(1));
  });

  // Случайный выбор голоса и сокращение урока раньше могли вытеснить
  // письмо по памяти. Все три режима нужны каждой букве, даже при
  // плотном плане и уже накопленном прогрессе.
  test('три обязательных режима сохраняются при 3–5 встречах', () {
    for (final count in [3, 4, 5]) {
      for (final state in AtomState.values) {
        for (var seed = 0; seed < 30; seed++) {
          final ex =
              ExerciseGenerator(
                curriculum: curriculum,
                rules: LearningRules(tasksPerSession: count * 2 + 1),
                random: Random(seed),
              ).build(
                plan: planOf(
                  newAtoms: state == AtomState.fresh ? [ba, ta] : [],
                  review: state == AtomState.fresh ? [] : [ba.id, ta.id],
                  spaced: [siin.id],
                ),
                ctx: ctxOf({
                  ...others,
                  for (final a in [ba, ta])
                    a.id: AtomProgress(
                      state: state,
                      hadActiveSuccess: state.index >= AtomState.learning.index,
                    ),
                }),
                sessionId: 2,
              );
          expect(ex, hasLength(count * 2 + 1));
          expect(ex.last.atom, siin);
          for (final atom in [ba, ta]) {
            final modes = modesOf(ex, atom);
            expect(modes, hasLength(count));
            expect(modes.where((m) => m.isActive), [
              ExerciseMode.trace,
              ExerciseMode.traceFromMemory,
              ExerciseMode.sayName,
            ]);
          }
        }
      }
    }
  });

  // Раньше генератор молча удалял часть обещанных букв из широкого плана.
  // Такой план нужно пересоставить до начала урока, а не сокращать на ходу.
  test('слишком широкий план нельзя превратить в неполный урок', () {
    final letters = [
      for (var i = 0; i < 8; i++) letter('letter$i', tracing: 'shape$i'),
    ];
    final wideCurriculum = Curriculum(
      topics: const [],
      nodes: [
        for (final atom in letters)
          CurriculumNode(atom: atom, requirement: const Always()),
      ],
    );
    expect(
      () => ExerciseGenerator(curriculum: wideCurriculum).build(
        plan: planOf(
          newAtoms: [letters.last],
          review: letters.take(7).map((a) => a.id).toList(),
        ),
        ctx: ctxOf({for (final a in letters.take(7)) a.id: introduced}),
        sessionId: 2,
      ),
      throwsStateError,
    );
  });
}
