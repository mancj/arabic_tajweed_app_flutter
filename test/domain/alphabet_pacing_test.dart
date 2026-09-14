import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Темп алфавита: после одного урока с новым материалом в тот же день
/// нужны два успешных полноценных повторения. На новом дне цикл открыт.
void main() {
  final curriculum = CurriculumLoader.merge([
    for (final stage in ['stage1', 'stage2'])
      CurriculumLoader.parse(
        File('assets/curriculum/$stage.json').readAsStringSync(),
      ),
  ]);
  final planner = LessonPlanner(curriculum: curriculum);

  CurriculumContext afterTopics(int count, {int lastSeenSession = 1}) {
    final progress = <String, AtomProgress>{};
    for (final (index, topic) in curriculum.topics.take(count).indexed) {
      for (final id in topic.counterOf) {
        final atom = curriculum.nodes
            .firstWhere((node) => node.atom.id == id)
            .atom;
        progress[id] = AtomProgress(
          state: atom.kind == AtomKind.concept
              ? AtomState.introduced
              : AtomState.known,
          weak: atom.kind != AtomKind.concept,
          introducedSession: index + 1,
          lastSeenSession: lastSeenSession,
        );
      }
    }
    return CurriculumContext(
      progress: progress,
      formsByLetter: curriculum.formsByLetter,
    );
  }

  LessonPlan plan(
    CurriculumContext context,
    PacingSnapshot pacing, {
    int sessionId = 30,
  }) => planner.plan(
    ctx: context,
    sessionId: sessionId,
    sessionsWithoutNew: 10,
    pacing: pacing,
  );

  test('в алфавите ровно 28 изолированных букв', () {
    expect(curriculum.baseLetters, hasLength(28));
    expect(
      curriculum.baseLetters,
      everyElement(
        isA<Atom>()
            .having((atom) => atom.kind, 'kind', AtomKind.letterForm)
            .having((atom) => atom.form, 'form', LetterForm.isolated),
      ),
    );
  });

  test('после нового урока формы ждут два повторения', () {
    final context = afterTopics(1);

    final firstReview = plan(
      context,
      const PacingSnapshot(enabled: true, hasNewMaterialToday: true),
    );
    expect(firstReview.purpose, LessonPurpose.mixedReview);
    expect(firstReview.newAtoms, isEmpty);

    final secondReview = plan(
      context,
      const PacingSnapshot(
        enabled: true,
        hasNewMaterialToday: true,
        successfulReviewsSinceLatestNew: 1,
      ),
    );
    expect(secondReview.purpose, LessonPurpose.mixedReview);

    final forms = plan(
      context,
      const PacingSnapshot(
        enabled: true,
        hasNewMaterialToday: true,
        successfulReviewsSinceLatestNew: 2,
      ),
    );
    expect(forms.purpose, LessonPurpose.standard);
    expect(forms.topicId, 'm.forms');
    expect(forms.newAtoms, isNotEmpty);
  });

  test('урок форм тоже начинает новый цикл повторений', () {
    final result = plan(
      afterTopics(2),
      const PacingSnapshot(enabled: true, hasNewMaterialToday: true),
    );

    expect(result.purpose, LessonPurpose.mixedReview);
    expect(result.newAtoms, isEmpty);
  });

  test('новый календарный день сразу разрешает следующий урок', () {
    final result = plan(afterTopics(1), const PacingSnapshot(enabled: true));

    expect(result.topicId, 'm.forms');
    expect(result.newAtoms, isNotEmpty);
  });

  test('темп действует и перед хамзой, а не только перед буквами', () {
    final result = plan(
      afterTopics(22),
      const PacingSnapshot(enabled: true, hasNewMaterialToday: true),
    );

    expect(result.purpose, LessonPurpose.mixedReview);
    expect(result.newAtoms, isEmpty);
  });

  test('после семи букв сначала заканчиваются их формы', () {
    final result = plan(afterTopics(3), const PacingSnapshot(enabled: true));

    expect(result.topicId, 'm.jim.forms');
    expect(result.purpose, LessonPurpose.standard);
  });

  test('рубеж после семи букв блокирует следующую группу', () {
    final result = plan(afterTopics(4), const PacingSnapshot(enabled: true));

    expect(result.purpose, LessonPurpose.alphabetCheckpoint);
    expect(result.checkpointLetters, 7);
    expect(result.newAtoms, isEmpty);
    expect(result.reviewCounts.values.reduce((a, b) => a + b), 20);
    expect(
      result.reviewAtoms,
      containsAll(curriculum.baseLetters.take(7).map((atom) => atom.id)),
    );
  });

  test('рубеж может быть первым из двух повторений', () {
    final context = afterTopics(4);
    final oneReview = plan(
      context,
      const PacingSnapshot(
        enabled: true,
        hasNewMaterialToday: true,
        successfulReviewsSinceLatestNew: 1,
        completedAlphabetCheckpoints: {7},
      ),
    );
    expect(oneReview.purpose, LessonPurpose.mixedReview);

    final ready = plan(
      context,
      const PacingSnapshot(
        enabled: true,
        hasNewMaterialToday: true,
        successfulReviewsSinceLatestNew: 2,
        completedAlphabetCheckpoints: {7},
      ),
    );
    expect(ready.topicId, 'm.nojoin');
    expect(ready.newAtoms, isNotEmpty);
  });

  test('повторения не позволяют обойти обязательный рубеж', () {
    final result = plan(
      afterTopics(10),
      const PacingSnapshot(
        enabled: true,
        hasNewMaterialToday: true,
        successfulReviewsSinceLatestNew: 20,
        completedAlphabetCheckpoints: {7},
      ),
    );

    expect(result.purpose, LessonPurpose.alphabetCheckpoint);
    expect(result.checkpointLetters, 15);
  });

  test('старый прогресс не ставит четыре рубежа подряд', () {
    final before = plan(afterTopics(23), const PacingSnapshot(enabled: true));
    expect(before.purpose, LessonPurpose.alphabetCheckpoint);
    expect(before.checkpointLetters, 28);

    final after = plan(
      afterTopics(23),
      const PacingSnapshot(enabled: true, completedAlphabetCheckpoints: {28}),
    );
    expect(after.purpose, isNot(LessonPurpose.alphabetCheckpoint));
  });

  test('смешанный повтор включает уже пройденные соединённые формы', () {
    final result = plan(
      afterTopics(2),
      const PacingSnapshot(enabled: true, hasNewMaterialToday: true),
    );

    expect(result.reviewAtoms, contains('ba.initial'));
    expect(result.reviewAtoms, contains('alif.isolated'));
    final recentFormIds = curriculum.topics[1].counterOf.toSet();
    final recentTasks = result.reviewCounts.entries
        .where((entry) => recentFormIds.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);
    expect(recentTasks, lessThanOrEqualTo(8));
  });

  test('обычный новый урок всё равно содержит старый материал', () {
    final result = plan(
      afterTopics(2, lastSeenSession: 30),
      const PacingSnapshot(enabled: true),
      sessionId: 30,
    );

    expect(result.topicId, 'm.jim');
    expect(result.newAtoms.where(_isBaseLetter), hasLength(3));
    expect(result.spacedReview, isNotEmpty);
  });
}

bool _isBaseLetter(Atom atom) =>
    atom.kind == AtomKind.letterForm &&
    atom.letterId != null &&
    atom.form == LetterForm.isolated;
