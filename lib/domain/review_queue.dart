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

  /// Кандидаты для урока с новым материалом: сначала сохраняем всё, что
  /// действительно созрело, затем добираем знакомое даже до интервала.
  /// После первого набора начало списка поровну чередует последнюю волну
  /// и более старые знания — именно первые элементы получат резерв урока.
  List<String> buildMixed(
    CurriculumContext ctx, {
    required int sessionId,
    Set<String> exclude = const {},
    required Curriculum curriculum,
  }) {
    final due = build(
      ctx,
      sessionId: sessionId,
      exclude: exclude,
      curriculum: curriculum,
    );
    final drillable = {
      for (final node in curriculum.nodes)
        if (node.atom.kind != AtomKind.concept) node.atom.id,
    };
    final fallback = ctx.progress.entries
        .where(
          (entry) =>
              drillable.contains(entry.key) &&
              !exclude.contains(entry.key) &&
              entry.value.state != AtomState.fresh &&
              !entry.value.isDeferredAt(sessionId, rules),
        )
        .sorted(
          (a, b) => (a.value.lastSeenSession ?? 0).compareTo(
            b.value.lastSeenSession ?? 0,
          ),
        )
        .map((entry) => entry.key);
    final candidates = <String>{...due, ...fallback}.toList();
    final latestSession = candidates
        .map(
          (id) =>
              ctx.progress[id]?.introducedSession ??
              ctx.progress[id]?.lastSeenSession ??
              0,
        )
        .maxOrNull;
    if (latestSession == null) return const [];

    final recent = <String>[];
    final older = <String>[];
    for (final id in candidates) {
      final progress = ctx.progress[id]!;
      final introduced =
          progress.introducedSession ?? progress.lastSeenSession ?? 0;
      (introduced == latestSession ? recent : older).add(id);
    }
    if (older.isEmpty) return candidates.take(rules.reviewQueueCap).toList();

    final mixed = <String>[];
    for (
      var index = 0;
      mixed.length < rules.reviewQueueCap &&
          (index < older.length || index < recent.length);
      index++
    ) {
      if (index < older.length) mixed.add(older[index]);
      if (mixed.length == rules.reviewQueueCap) break;
      if (index < recent.length) mixed.add(recent[index]);
    }
    return mixed;
  }

  static int _urgency(AtomProgress p) =>
      p.state.index < AtomState.known.index ? 0 : 1;
}
