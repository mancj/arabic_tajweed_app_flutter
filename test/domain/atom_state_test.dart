import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';

const rules = LearningRules();
const fold = ProgressFold(rules: rules, letterFormIds: {});
const letterFold = ProgressFold(rules: rules, letterFormIds: {'ba.isolated'});
final t0 = DateTime(2026, 1, 1);

ProgressEvent answer({
  bool correct = true,
  int attempt = 1,
  bool fast = true,
  ExerciseMode mode = ExerciseMode.formToName,
  int session = 1,
  Duration offset = Duration.zero,
}) => ProgressEvent(
  atomId: 'ba.isolated',
  mode: mode,
  sessionId: session,
  correct: correct,
  attempt: attempt,
  fastEnough: fast,
  at: t0.add(offset),
);

AtomProgress run(List<LogEntry> log) => fold.fold(log)['ba.isolated']!;
AtomProgress runLetter(List<LogEntry> log) =>
    letterFold.fold(log)['ba.isolated']!;

void main() {
  test('введённый атом переходит в learning с первого ответа', () {
    final p = run([
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: t0),
      answer(),
    ]);
    expect(p.state, AtomState.learning);
  });

  test('трёх верных в одном режиме недостаточно для known', () {
    final p = run([answer(), answer(), answer(), answer()]);
    expect(p.state, AtomState.learning);
  });

  test('три верных подряд в двух режимах дают known', () {
    final p = run([
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.nameToForm),
    ]);
    expect(p.state, AtomState.known);
  });

  // Медленное правильное письмо не должно запирать начальное обучение.
  // При этом автоматизм и подтверждения после known требуют скорости.
  test('медленные верные ответы дают known, но не ускоряют интервалы', () {
    final p = run([
      answer(fast: false, mode: ExerciseMode.trace),
      answer(fast: false, mode: ExerciseMode.traceFromMemory),
      answer(fast: false, mode: ExerciseMode.sayName),
      answer(fast: false, session: 2, offset: const Duration(days: 2)),
    ]);
    expect(p.cleanStreak, 3);
    expect(p.state, AtomState.known);
    expect(p.cleanSinceKnown, 0);
    expect(p.confirmations, 0);
    expect(p.reviewIntervalFor(rules), rules.reviewIntervalBase);
  });

  test('чистые повторы в known удваивают интервал, ошибка обнуляет', () {
    const rules = LearningRules();
    final known = run([
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
    ]);
    expect(known.state, AtomState.known);
    expect(known.reviewIntervalFor(rules), rules.reviewIntervalBase);

    final twice = run([
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(),
      answer(),
    ]);
    expect(twice.reviewIntervalFor(rules), rules.reviewIntervalBase * 4);

    final failed = run([
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(),
      answer(correct: false),
    ]);
    expect(failed.state, AtomState.learning);
    expect(
      failed.reviewIntervalFor(rules),
      0,
      reason: 'недоученный — каждый урок',
    );
  });

  // Буквы закрепляются встречами в разных занятиях, а не числом ответов
  // внутри одного урока или прошедшими календарными днями.
  test('буква доходит до mastered через интервалы 1, 2 и 4 сессии', () {
    final known = <LogEntry>[
      answer(mode: ExerciseMode.trace),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.trace),
    ];
    final first = runLetter([...known, answer(session: 2), answer(session: 2)]);
    expect(first.confirmations, 1);
    expect(first.reviewIntervalFor(rules, isLetterForm: true), 2);

    final second = runLetter([
      ...known,
      answer(session: 2),
      answer(session: 2),
      answer(session: 4),
    ]);
    expect(second.confirmations, 2);
    expect(second.state, AtomState.known);

    final mastered = runLetter([
      ...known,
      answer(session: 2),
      answer(session: 4),
      answer(session: 8),
    ]);
    expect(mastered.confirmations, 3);
    expect(mastered.state, AtomState.mastered);
  });

  test('ошибка обнуляет подтверждения буквы', () {
    final p = runLetter([
      answer(mode: ExerciseMode.trace),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.trace),
      answer(session: 2),
      answer(correct: false, session: 3),
    ]);
    expect(p.state, AtomState.learning);
    expect(p.confirmations, 0);
  });

  test('ответ со второй попытки не двигает вперёд', () {
    final p = run([answer(attempt: 2), answer(attempt: 2)]);
    expect(p.cleanStreak, 0);
  });

  test('ошибка сбрасывает known на learning, а не в ноль', () {
    final p = run([
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.nameToForm),
      answer(correct: false),
    ]);
    expect(p.state, AtomState.learning);
    expect(p.cleanStreak, 0);
  });

  test('пять ошибок откладывают атом', () {
    final p = run([for (var i = 0; i < 5; i++) answer(correct: false)]);
    expect(p.deferCount, 1);
    expect(p.isDeferredAt(1, rules), isTrue);
    expect(p.isDeferredAt(1 + rules.deferSessions, rules), isFalse);
  });

  test('ошибки в трёх разных сессиях откладывают атом', () {
    final p = run([
      answer(correct: false, session: 1),
      answer(correct: false, session: 2),
      answer(correct: false, session: 3),
    ]);
    expect(p.deferCount, 1);
  });

  test('после двух откладываний срабатывает облегчённый критерий', () {
    final log = <LogEntry>[];
    for (var defer = 0; defer < 2; defer++) {
      for (var s = 0; s < 3; s++) {
        log.add(answer(correct: false, session: defer * 10 + s));
      }
    }
    log.add(answer(session: 100));
    final p = run(log);
    expect(p.deferCount, 2);
    expect(p.state, AtomState.known);
  });

  test('без активной механики атом не доходит до mastered', () {
    final log = <LogEntry>[
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.nameToForm),
    ];
    var offset = const Duration(days: 1);
    for (final delay in rules.confirmDelays) {
      offset += delay;
      log.add(answer(offset: offset));
    }
    final p = run(log);
    expect(p.state, AtomState.known);
    expect(p.confirmations, rules.confirmDelays.length);
  });

  test('с обводкой и всеми интервалами атом доходит до mastered', () {
    final log = <LogEntry>[
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.trace),
    ];
    var offset = Duration.zero;
    for (final delay in rules.confirmDelays) {
      offset += delay;
      log.add(answer(offset: offset));
    }
    expect(run(log).state, AtomState.mastered);
  });

  test('подтверждение раньше интервала не засчитывается', () {
    final p = run([
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.trace),
      answer(offset: const Duration(hours: 1)),
    ]);
    expect(p.confirmations, 0);
    expect(p.state, AtomState.known);
  });
}
