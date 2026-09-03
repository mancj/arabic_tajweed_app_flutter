import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'learning_rules.dart';

/// Очередь интервального повторения: что пора показать снова.
///
/// Общая для всего курса, а не для отдельной темы. Без неё урок по теме
/// спрашивал бы только её собственные буквы, и старое не возвращалось бы
/// никогда — а в этом и весь смысл интервального повторения.
class ReviewQueue {
  const ReviewQueue({this.rules = const LearningRules()});

  final LearningRules rules;

  /// Атомы в порядке «кого дольше всего не показывали».
  ///
  /// [exclude] — атомы, которые урок и так спросит: повторять их вторым
  /// заходом незачем. Отложенные и полностью освоенные не берутся.
  List<String> build(
    CurriculumContext ctx, {
    required int sessionId,
    Set<String> exclude = const {},
    Curriculum? curriculum,
  }) {
    final drillable = curriculum == null
        ? null
        : {
            for (final node in curriculum.nodes)
              if (node.atom.kind != AtomKind.concept) node.atom.id,
          };

    return ctx.progress.entries
        .where(
          (e) =>
              !exclude.contains(e.key) &&
              e.value.state != AtomState.fresh &&
              e.value.state != AtomState.mastered &&
              !e.value.isDeferredAt(sessionId, rules) &&
              (drillable?.contains(e.key) ?? true),
        )
        .sortedBy<num>((e) => e.value.lastSeenSession ?? 0)
        .take(rules.reviewQueueCap)
        .map((e) => e.key)
        .toList();
  }
}
