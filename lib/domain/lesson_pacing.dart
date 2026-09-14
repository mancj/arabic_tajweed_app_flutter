import 'learning_rules.dart';

/// Зачем было собрано занятие. Обычный повтор лечит пробелы, а смешанный
/// регулирует темп выдачи нового материала алфавита.
enum LessonPurpose {
  standard,
  mixedReview,
  alphabetCheckpoint;

  bool get isMixedReview => this == mixedReview || this == alphabetCheckpoint;
}

/// Всё, что планировщику нужно знать о темпе на текущий местный день.
/// Источник истины остаётся в журнале: снимок пересчитывается при открытии
/// курса и после каждого завершённого занятия.
class PacingSnapshot {
  const PacingSnapshot({
    this.enabled = false,
    this.hasNewMaterialToday = false,
    this.successfulReviewsSinceLatestNew = 0,
    this.completedAlphabetCheckpoints = const {},
  });

  final bool enabled;
  final bool hasNewMaterialToday;
  final int successfulReviewsSinceLatestNew;
  final Set<int> completedAlphabetCheckpoints;

  bool canIntroduceNewMaterial(LearningRules rules) =>
      !enabled ||
      !hasNewMaterialToday ||
      successfulReviewsSinceLatestNew >= rules.reviewsBeforeNextNewLesson;

  int reviewsUntilNewMaterial(LearningRules rules) => hasNewMaterialToday
      ? (rules.reviewsBeforeNextNewLesson - successfulReviewsSinceLatestNew)
            .clamp(0, rules.reviewsBeforeNextNewLesson)
      : 0;
}
