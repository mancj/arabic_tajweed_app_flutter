import 'curriculum.dart';
import 'learning_rules.dart';
import 'lesson_pacing.dart';
import 'planner.dart';

/// Решает, чем заполнить оставшуюся часть занятия. Даты и прогресс получает
/// готовыми значениями; контроллер отвечает лишь за переход между экранами.
class LessonPlanContinuation {
  const LessonPlanContinuation({required this.curriculum, required this.rules});

  final Curriculum curriculum;
  final LearningRules rules;

  LessonPlan? next({
    required CurriculumContext context,
    required int sessionId,
    required int sessionsWithoutNew,
    required int remaining,
    required Map<String, int> previousCounts,
    required PacingSnapshot pacing,
  }) {
    final planner = LessonPlanner(curriculum: curriculum, rules: rules);
    var plan = planner.plan(
      ctx: context,
      sessionId: sessionId,
      sessionsWithoutNew: sessionsWithoutNew,
      previousCounts: previousCounts,
      pacing: pacing,
    );
    if (plan.minimumTaskCount(curriculum, rules) > remaining) {
      plan = planner.practicePlan(
        ctx: context,
        sessionId: sessionId,
        taskLimit: remaining,
        previousCounts: previousCounts,
      );
    }
    return _hasWork(plan) ? plan : null;
  }

  LessonPlan? replaceUnavailablePronunciation({
    required CurriculumContext context,
    required int sessionId,
    required int remaining,
    required Map<String, int> previousCounts,
    Set<String>? atomIds,
  }) {
    final plan = LessonPlanner(curriculum: curriculum, rules: rules)
        .practicePlan(
          ctx: context,
          sessionId: sessionId,
          taskLimit: remaining,
          previousCounts: previousCounts,
          atomIds: atomIds,
        );
    return plan.minimumTaskCount(curriculum, rules) > 0 ? plan : null;
  }

  bool _hasWork(LessonPlan plan) =>
      plan.minimumTaskCount(curriculum, rules) > 0 ||
      plan.newAtoms.isNotEmpty ||
      plan.reviewAtoms.isNotEmpty;
}
