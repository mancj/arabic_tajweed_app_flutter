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

  /// Атомы, которым пора в повтор, в порядке срочности: сначала
  /// недоученные (до `known`), они просятся каждый урок; затем выученные,
  /// у которых вышел интервал, — раньше те, кто ждёт дольше. Выученный
  /// атом, чей интервал ещё не вышел, в очередь не попадает вовсе:
  /// в этом и смысл интервального повторения. См. ТЗ §6.2.
  ///
  /// [exclude] — атомы, которые урок и так спросит: повторять их вторым
  /// заходом незачем. Отложенные и полностью освоенные не берутся.
  List<String> build(
    CurriculumContext ctx, {
    required int sessionId,
    Set<String> exclude = const {},
    Curriculum? curriculum,
  }) {
    final letterFormIds = curriculum?.letterFormIds ?? const <String>{};
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
              e.value.isDueAt(
                sessionId,
                rules,
                isLetterForm: letterFormIds.contains(e.key),
              ) &&
              (drillable?.contains(e.key) ?? true),
        )
        .sorted((a, b) {
          final byState = _urgency(a.value).compareTo(_urgency(b.value));
          if (byState != 0) return byState;
          return a.value
              .dueSession(rules, isLetterForm: letterFormIds.contains(a.key))
              .compareTo(
                b.value.dueSession(
                  rules,
                  isLetterForm: letterFormIds.contains(b.key),
                ),
              );
        })
        .take(rules.reviewQueueCap)
        .map((e) => e.key)
        .toList();
  }

  static int _urgency(AtomProgress p) =>
      p.state.index < AtomState.known.index ? 0 : 1;
}
