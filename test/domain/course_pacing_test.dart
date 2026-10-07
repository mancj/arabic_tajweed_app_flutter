import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Дневной цикл должен ограничивать новый материал не только в алфавите:
/// без этой проверки огласовки, связки и слова снова шли подряд в один день.
void main() {
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final planner = LessonPlanner(curriculum: curriculum);

  CurriculumContext beforeTopic(String topicId) {
    final target = curriculum.topics.indexWhere((topic) => topic.id == topicId);
    final progress = <String, AtomProgress>{};
    for (final (topicIndex, topic) in curriculum.topics.take(target).indexed) {
      for (final id in topic.counterOf) {
        final atom = curriculum.nodes
            .firstWhere((node) => node.atom.id == id)
            .atom;
        progress[id] = AtomProgress(
          state: atom.kind == AtomKind.concept
              ? AtomState.introduced
              : AtomState.known,
          weak: atom.kind != AtomKind.concept,
          introducedSession: topicIndex + 1,
          lastSeenSession: topicIndex + 1,
        );
      }
    }
    return CurriculumContext(
      progress: progress,
      formsByLetter: curriculum.formsByLetter,
    );
  }

  LessonPlan plan(String topicId, {int successfulReviews = 0}) => planner.plan(
    ctx: beforeTopic(topicId),
    sessionId: 100,
    sessionsWithoutNew: 10,
    pacing: PacingSnapshot(
      enabled: true,
      hasNewMaterialToday: true,
      successfulReviewsSinceLatestNew: successfulReviews,
      completedAlphabetCheckpoints: const {28},
    ),
  );

  Set<String> idsInStage(int stage) => curriculum.topics
      .where((topic) => topic.stage == stage)
      .expand((topic) => topic.counterOf)
      .toSet();

  // После перехода в новый раздел старые буквы не должны возвращаться ни в
  // обычном уроке, ни в дневном повторении, ни при доборе длины занятия.
  test('автоматические задания ограничены текущим разделом', () {
    for (final (topicId, stage) in const [
      ('m.haraka.signs', 2),
      ('m.haraka.group1', 2),
      ('m.join', 3),
      ('m.haraka.words2', 3),
    ]) {
      final ctx = beforeTopic(topicId);
      final ids = idsInStage(stage);
      final next = planner.plan(
        ctx: ctx,
        sessionId: 100,
        sessionsWithoutNew: 10,
        pacing: const PacingSnapshot(
          enabled: true,
          completedAlphabetCheckpoints: {28},
        ),
      );
      expect(next.topicId, topicId);
      expect(next.reviewAtoms.every(ids.contains), isTrue);
      expect(next.spacedReview.every(ids.contains), isTrue);

      if (topicId == 'm.haraka.group1' || topicId == 'm.haraka.words2') {
        final repeated = plan(topicId);
        expect(repeated.purpose, LessonPurpose.mixedReview);
        expect(repeated.reviewAtoms, isNotEmpty);
        expect(repeated.reviewAtoms.every(ids.contains), isTrue);
      }

      final filler = planner.practicePlan(
        ctx: ctx,
        sessionId: 100,
        taskLimit: 8,
      );
      expect(filler.reviewAtoms.every(ids.contains), isTrue);
    }
  });

  test('прошлый раздел не задерживает переход до mastered', () {
    final ctx = beforeTopic('m.haraka.signs');
    expect(ctx.progress['ba.isolated']!.state, AtomState.known);
    final next = planner.plan(
      ctx: ctx,
      sessionId: 100,
      sessionsWithoutNew: 10,
      pacing: const PacingSnapshot(
        enabled: true,
        completedAlphabetCheckpoints: {28},
      ),
    );
    expect(next.topicId, 'm.haraka.signs');
  });

  test('первый блок нового раздела не ждёт повторы старого', () {
    for (final topicId in ['m.haraka.intro', 'm.join']) {
      final ctx = beforeTopic(topicId);
      final next = planner.plan(
        ctx: ctx,
        sessionId: 100,
        sessionsWithoutNew: 0,
        pacing: const PacingSnapshot(
          enabled: true,
          hasNewMaterialToday: true,
          completedAlphabetCheckpoints: {28},
        ),
      );
      expect(next.topicId, topicId);
      expect(next.purpose, LessonPurpose.standard);
      expect(next.spacedReview, isEmpty);
    }
  });

  test('после ошибки в старом разделе путь остаётся в новом', () {
    final ctx = beforeTopic('m.haraka.group1');
    ctx.progress['ba.isolated'] = ctx.progress['ba.isolated']!.copyWith(
      state: AtomState.learning,
    );
    final next = planner.plan(
      ctx: ctx,
      sessionId: 100,
      sessionsWithoutNew: 10,
      pacing: const PacingSnapshot(
        enabled: true,
        completedAlphabetCheckpoints: {28},
      ),
    );
    expect(next.topicId, 'm.haraka.group1');
    expect(next.reviewAtoms.every(idsInStage(2).contains), isTrue);
  });

  test('старый раздел можно повторить по выбору пользователя', () {
    final ctx = beforeTopic('m.haraka.group1');
    final topic = curriculum.topics.firstWhere((topic) => topic.id == 'm.jim');
    final repeated = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
    expect(repeated.reviewAtoms, isNotEmpty);
    expect(repeated.spacedReview.every(idsInStage(1).contains), isTrue);
  });

  for (final (topicId, previousAtomId) in const [
    ('m.haraka.group1', 'haraka.fatha'),
    ('m.break', 'syl.ba_ta'),
    ('m.haraka.words2', 'word.kataba'),
  ]) {
    test('перед $topicId в тот же день идут два повтора', () {
      final firstReview = plan(topicId);
      expect(firstReview.purpose, LessonPurpose.mixedReview);
      expect(firstReview.newAtoms, isEmpty);
      expect(firstReview.reviewAtoms, contains(previousAtomId));

      final secondReview = plan(topicId, successfulReviews: 1);
      expect(secondReview.purpose, LessonPurpose.mixedReview);

      final nextLesson = plan(topicId, successfulReviews: 2);
      expect(nextLesson.purpose, LessonPurpose.standard);
      expect(nextLesson.topicId, topicId);
      expect(nextLesson.newAtoms, isNotEmpty);
    });
  }
}
