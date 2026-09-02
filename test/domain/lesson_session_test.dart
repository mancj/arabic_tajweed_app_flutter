import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

Atom letter(String id) =>
    Atom(id: id, kind: AtomKind.letterForm, display: id, letterId: id);

Exercise ex(String id) => Exercise(
  atom: letter(id),
  mode: ExerciseMode.formToName,
  options: [letter(id), letter('$id-x'), letter('$id-y')],
  answerIndex: 0,
  level: DistractorLevel.distant,
);

LessonSession session(int count) => LessonSession(
  exercises: [for (var i = 0; i < count; i++) ex('a$i')],
  sessionId: 1,
  now: () => DateTime(2026, 1, 1),
);

void main() {
  test('верный ответ двигает к следующему заданию', () {
    final s = session(3);
    expect(s.answer(s.current!, 0, fastEnough: true), AnswerOutcome.correct);
    expect(s.current!.atom.id, 'a1');
  });

  test('несколько промахов подряд не плодят копии задания', () {
    final s = session(6);
    final first = s.current!;

    // Человек остаётся на провальном задании до верного ответа. Каждый
    // промах не должен добавлять ещё одну копию в очередь.
    for (var i = 0; i < 5; i++) {
      expect(s.answer(first, 1, fastEnough: true), AnswerOutcome.wrong);
    }
    s.answer(first, 0, fastEnough: true);

    final ids = s.queueIds;
    expect(ids.where((id) => id == first.atom.id), hasLength(2));
  });

  test('провал возвращается через несколько заданий, а не в конец', () {
    final s = session(8);
    final first = s.current!;
    s.answer(first, 1, fastEnough: true);
    s.answer(first, 0, fastEnough: true);

    // Сразу — ответит по памяти, в самый конец — забудет разбор.
    final ids = s.queueIds;
    final positions = [
      for (var i = 0; i < ids.length; i++)
        if (ids[i] == first.atom.id) i,
    ];
    expect(positions.last, lessThan(ids.length - 1));
    expect(positions.last, greaterThan(positions.first + 1));
  });

  test('ошибка возвращает задание в очередь', () {
    final s = session(3);
    final first = s.current!;
    expect(s.answer(first, 1, fastEnough: true), AnswerOutcome.wrong);
    expect(s.current, first, reason: 'остаёмся на нём до верного ответа');

    s.answer(first, 0, fastEnough: true);
    expect(s.current!.atom.id, 'a1');

    s.answer(s.current!, 0, fastEnough: true);
    s.answer(s.current!, 0, fastEnough: true);
    expect(s.current, first, reason: 'провал вернулся в очередь');
  });

  test('повторная попытка пишется в лог как attempt 2', () {
    final s = session(2);
    final first = s.current!;
    s.answer(first, 1, fastEnough: true);
    s.answer(first, 0, fastEnough: true);

    final events = s.log.cast<ProgressEvent>();
    expect(events.map((e) => e.attempt), [1, 2]);
    expect(events.map((e) => e.correct), [false, true]);
  });

  test('очередь не растёт выше потолка', () {
    const rules = LearningRules();
    final s = LessonSession(
      exercises: [for (var i = 0; i < rules.tasksPerSession; i++) ex('a$i')],
      sessionId: 1,
      rules: rules,
      now: () => DateTime(2026, 1, 1),
    );
    for (var i = 0; i < 10; i++) {
      final e = s.current!;
      s.answer(e, 1, fastEnough: true);
      s.answer(e, 0, fastEnough: true);
    }
    expect(s.total, rules.maxTasksPerSession);
  });

  test('сессия заканчивается, когда очередь пройдена', () {
    final s = session(2);
    s.answer(s.current!, 0, fastEnough: true);
    s.answer(s.current!, 0, fastEnough: true);
    expect(s.isFinished, isTrue);
    expect(s.progress, 1);
  });
}
