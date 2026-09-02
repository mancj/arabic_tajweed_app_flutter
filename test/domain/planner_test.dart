import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';

const rules = LearningRules();

Atom letter(String id) =>
    Atom(id: id, kind: AtomKind.letterForm, display: id, letterId: id);

final curriculum = Curriculum(
  topics: const [],
  nodes: [
    for (var i = 0; i < 20; i++)
      CurriculumNode(atom: letter('l$i'), requirement: const Always()),
  ],
);

CurriculumContext ctx(Map<String, AtomProgress> progress) =>
    CurriculumContext(progress: progress, formsByLetter: const {});

AtomProgress learning({int? deferredAt}) => AtomProgress(
  state: AtomState.learning,
  deferredAtSession: deferredAt,
  deferCount: deferredAt == null ? 0 : 1,
);

void main() {
  final planner = LessonPlanner(curriculum: curriculum, loadThreshold: 8);

  test('на пустом старте вводится столько, чтобы набрался урок', () {
    // Задания строятся выбором из введённых атомов: пока их мало, урок
    // не набирается, поэтому первые уроки вводят больше обычного.
    final plan = planner.plan(
      ctx: ctx({}),
      sessionId: 1,
      sessionsWithoutNew: 0,
    );
    expect(plan.newAtoms.length, 4);
    expect(plan.template, LessonTemplate.newLetter);
  });

  test('когда атомов хватает, вводятся обычные два', () {
    final progress = {
      for (var i = 0; i < 5; i++)
        'l$i': const AtomProgress(state: AtomState.known),
    };
    final plan = planner.plan(
      ctx: ctx(progress),
      sessionId: 1,
      sessionsWithoutNew: 0,
    );
    expect(plan.newAtoms.length, 2);
  });

  test('нагрузка выше порога даёт закрепление без новых атомов', () {
    final progress = {for (var i = 0; i < 9; i++) 'a$i': learning()};
    final plan = planner.plan(
      ctx: ctx(progress),
      sessionId: 1,
      sessionsWithoutNew: 0,
    );
    expect(plan.template, LessonTemplate.consolidation);
    expect(plan.newAtoms, isEmpty);
  });

  test('гарантия темпа сильнее нагрузки', () {
    final progress = {for (var i = 0; i < 9; i++) 'a$i': learning()};
    final plan = planner.plan(
      ctx: ctx(progress),
      sessionId: 1,
      sessionsWithoutNew: 2,
    );
    expect(plan.newAtoms.length, 1);
    expect(plan.reason, contains('гарантия темпа'));
  });

  test('потолок отложенных сильнее гарантии темпа', () {
    final progress = {
      for (var i = 0; i < 5; i++) 'd$i': learning(deferredAt: 1),
    };
    final plan = planner.plan(
      ctx: ctx(progress),
      sessionId: 1,
      sessionsWithoutNew: 5,
    );
    expect(plan.newAtoms, isEmpty);
    expect(plan.reason, contains('отложенных'));
  });

  test('при переполнении самый старый отложенный возвращается досрочно', () {
    final progress = {
      'old': learning(deferredAt: 1),
      for (var i = 0; i < 4; i++) 'd$i': learning(deferredAt: 3),
    };
    final plan = planner.plan(
      ctx: ctx(progress),
      sessionId: 3,
      sessionsWithoutNew: 0,
    );
    expect(plan.reviewAtoms.first, 'old');
  });

  test('отложенные не считаются нагрузкой', () {
    final progress = {
      for (var i = 0; i < 4; i++) 'd$i': learning(deferredAt: 1),
      for (var i = 0; i < 4; i++) 'a$i': learning(),
    };
    final plan = planner.plan(
      ctx: ctx(progress),
      sessionId: 1,
      sessionsWithoutNew: 0,
    );
    expect(plan.newAtoms, isNotEmpty);
  });
}
