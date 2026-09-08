import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/review_queue.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Блок повтора по ТЗ §6.2 приходит из общей очереди, а не из самой темы:
/// иначе буквы прошлых уроков не всплывают никогда.
void main() {
  const rules = LearningRules();
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  final board = TopicBoard(curriculum);

  CurriculumContext ctxOf(Map<String, AtomProgress> progress) =>
      CurriculumContext(progress: progress, formsByLetter: const {});

  // Первый урок пройден: четыре буквы знакомы, но не доведены до mastered.
  final afterFirstLesson = ctxOf({
    for (final id in [
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ])
      id: const AtomProgress(state: AtomState.known, lastSeenSession: 1),
  });

  Topic topicOf(String id) => curriculum.topics.firstWhere((t) => t.id == id);

  test('урок по второй теме возвращает буквы из первой', () {
    final plan = board.planFor(
      topicOf('m.forms'),
      afterFirstLesson,
      sessionId: 2,
    );

    expect(plan.spacedReview, isNotEmpty);
    expect(plan.spacedReview, contains('ba.isolated'));
  });

  test('в повтор не попадают буквы самой темы', () {
    final topic = topicOf('m.forms');
    final plan = board.planFor(topic, afterFirstLesson, sessionId: 2);

    expect(
      plan.spacedReview.where(topic.counterOf.contains),
      isEmpty,
      reason: 'тема и так их спросит, второй раз незачем',
    );
  });

  test('в уроке действительно появляются задания по старым буквам', () {
    final topic = topicOf('m.forms');
    final plan = board.planFor(topic, afterFirstLesson, sessionId: 2);

    final exercises = ExerciseGenerator(
      curriculum: curriculum,
      rules: rules,
      random: Random(7),
    ).build(plan: plan, ctx: afterFirstLesson, sessionId: 2);

    final asked = exercises.map((e) => e.atom.id).toSet();
    final fromOtherTopics = asked.where((id) => !topic.counterOf.contains(id));

    expect(fromOtherTopics, isNotEmpty);
    expect(exercises.length, rules.tasksPerSession);
  });

  test('повтор идёт блоком в конце, после закрепления по теме', () {
    final topic = topicOf('m.forms');
    final plan = board.planFor(topic, afterFirstLesson, sessionId: 2);

    final exercises = ExerciseGenerator(
      curriculum: curriculum,
      rules: rules,
      random: Random(7),
    ).build(plan: plan, ctx: afterFirstLesson, sessionId: 2);

    final firstOld = exercises.indexWhere(
      (e) => !topic.counterOf.contains(e.atom.id),
    );
    expect(firstOld, greaterThan(0));
    expect(
      exercises
          .skip(firstOld)
          .every((e) => !topic.counterOf.contains(e.atom.id)),
      isTrue,
      reason: 'сначала материал урока, потом старое — ТЗ §6.2',
    );
  });

  test('очередь отдаёт первыми тех, кого дольше не показывали', () {
    final ctx = ctxOf({
      'ba.isolated': const AtomProgress(
        state: AtomState.known,
        lastSeenSession: 5,
      ),
      'ta.isolated': const AtomProgress(
        state: AtomState.known,
        lastSeenSession: 1,
      ),
    });

    final queue = const ReviewQueue().build(ctx, sessionId: 9);
    expect(queue.first, 'ta.isolated');
  });

  test('освоенные и отложенные в очередь не идут', () {
    final ctx = ctxOf({
      'ba.isolated': const AtomProgress(state: AtomState.mastered),
      'ta.isolated': const AtomProgress(
        state: AtomState.learning,
        deferredAtSession: 9,
        deferCount: 1,
      ),
      'tha.isolated': const AtomProgress(state: AtomState.known),
    });

    expect(const ReviewQueue().build(ctx, sessionId: 9), ['tha.isolated']);
  });

  test('недоученные идут раньше освоенных, даже если показаны позже', () {
    final ctx = ctxOf({
      'ba.isolated': const AtomProgress(
        state: AtomState.known,
        lastSeenSession: 1,
      ),
      'jim.isolated': const AtomProgress(
        state: AtomState.learning,
        lastSeenSession: 7,
      ),
    });

    final queue = const ReviewQueue().build(ctx, sessionId: 9);
    expect(queue, ['jim.isolated', 'ba.isolated']);
  });

  test('узкая тема добирается повтором до полного урока', () {
    // Восемь букв известны, тема «айн» вводит только две.
    final ctx = ctxOf({
      for (final id in [
        'alif.isolated',
        'ba.isolated',
        'ta.isolated',
        'tha.isolated',
        'jim.isolated',
        'hha.isolated',
        'kha.isolated',
        'sin.isolated',
        'to.isolated',
        'zho.isolated',
      ])
        id: const AtomProgress(state: AtomState.known, lastSeenSession: 3),
    });
    final topic = topicOf('m.ayn');
    final plan = board.planFor(topic, ctx, sessionId: 4);

    final exercises = ExerciseGenerator(
      curriculum: curriculum,
      rules: rules,
      random: Random(7),
    ).build(plan: plan, ctx: ctx, sessionId: 4);

    final own = exercises.where((e) => topic.counterOf.contains(e.atom.id));
    expect(own, hasLength(6), reason: 'два новых атома по три задания');
    expect(exercises.length, rules.tasksPerSession);
  });
}
