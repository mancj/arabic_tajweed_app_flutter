import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Повторение возвращает пройденное, а не забегает вперёд. Раньше блок
/// повтора брал любой не-свежий атом, и в возврате к первому уроку
/// всплывали буквы из следующего — начатого и брошенного.
void main() {
  final curriculum = CurriculumLoader.merge([
    for (final name in ['stage1', 'stage2'])
      CurriculumLoader.parse(
        File('assets/curriculum/$name.json').readAsStringSync(),
      ),
  ]);
  final board = TopicBoard(curriculum);

  CurriculumContext ctxWith(Map<String, AtomState> states) => CurriculumContext(
    progress: {
      for (final e in states.entries) e.key: AtomProgress(state: e.value),
    },
    formsByLetter: const {},
  );

  test('повтор первой темы не тащит буквы из следующей', () {
    final first = curriculum.topics.first;
    final next = curriculum.topics[1];

    // Первая тема пройдена, следующая начата и брошена.
    final ctx = ctxWith({
      for (final id in first.counterOf) id: AtomState.known,
      next.counterOf[1]: AtomState.learning,
    });

    final plan = board.planFor(first, ctx);
    expect(plan.spacedReview, isNot(contains(next.counterOf[1])));
    expect(plan.newAtoms, isEmpty);
    expect(plan.reviewAtoms, first.counterOf);
  });

  test('тема, покрытая не полностью, доводит свои атомы', () {
    final first = curriculum.topics.first;

    // Понятие показано, буквы — нет: возврат должен их ввести.
    final ctx = ctxWith({first.counterOf.first: AtomState.introduced});
    final plan = board.planFor(first, ctx);

    expect(plan.newAtoms.map((a) => a.id), first.counterOf.skip(1));
    expect(plan.reviewAtoms, [first.counterOf.first]);
  });

  test('повтор поздней темы всё ещё возвращает прошлые буквы', () {
    final third = curriculum.topics[2];
    final ctx = ctxWith({
      for (final topic in curriculum.topics.take(3))
        for (final id in topic.counterOf) id: AtomState.known,
    });

    // Интервал выученного — две сессии: к третьей буквы первых тем уже пора.
    final plan = board.planFor(third, ctx, sessionId: 3);
    expect(plan.spacedReview, isNotEmpty);
    expect(
      plan.spacedReview.every((id) => !third.counterOf.contains(id)),
      isTrue,
    );
  });
}
