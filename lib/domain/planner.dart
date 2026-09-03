import 'dart:math';

import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'learning_rules.dart';
import 'review_queue.dart';

/// Шаблон урока. Не «урок 7», а урок такого типа. См. SPEC.md §6.2.
enum LessonTemplate { concept, newLetter, review, connection }

class LessonPlan {
  const LessonPlan({
    required this.template,
    required this.newAtoms,
    required this.reviewAtoms,
    required this.reason,
    this.spacedReview = const [],
  });

  final LessonTemplate template;
  final List<Atom> newAtoms;

  /// Атомы урока, которые уже знакомы: они идут в закрепление вместе с новыми.
  final List<String> reviewAtoms;

  /// Возврат старого из общей очереди — блок «повтор» по ТЗ §6.2.
  /// Это буквы из других тем, иначе они не всплывали бы никогда.
  final List<String> spacedReview;

  /// Какое правило сработало. Нужно для отладки и аналитики: без этого
  /// невозможно понять, почему у пользователя третью сессию нет новых букв.
  final String reason;
}

/// Планировщик. Четыре правила строго по приоритету — срабатывает первое
/// подходящее. Порядок и есть содержательное решение: гарантия темпа
/// сильнее нагрузки, но потолок отложенных сильнее гарантии темпа.
/// См. SPEC.md §6.3.
class LessonPlanner {
  const LessonPlanner({
    required this.curriculum,
    this.rules = const LearningRules(),
    this.loadThreshold = 8,
  });

  final Curriculum curriculum;
  final LearningRules rules;

  /// Выше этого числа активных атомов новые не вводятся.
  final int loadThreshold;

  LessonPlan plan({
    required CurriculumContext ctx,
    required int sessionId,
    required int sessionsWithoutNew,
  }) {
    final deferred = _deferred(ctx, sessionId);
    final review = _reviewQueue(ctx, sessionId);

    // 1. Потолок отложенных. Предохранитель на предохранитель: иначе
    //    человек формально не застревает, а фактически ничего не учит.
    if (deferred.length > rules.maxDeferred) {
      final revived = _oldestDeferred(ctx, deferred);
      return LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        // Досрочный возврат обязателен: иначе отложенные ждут своей паузы,
        // а урок-повторение работает вхолостую.
        reviewAtoms: [if (revived != null) revived, ...review],
        reason: 'отложенных ${deferred.length} > ${rules.maxDeferred}',
      );
    }

    final load = _load(ctx, sessionId);
    final available = curriculum.availableAtoms(ctx);

    // 2. Нагрузка выше порога — закрепление.
    final overloaded = load > loadThreshold;

    // 3. Гарантия темпа сильнее нагрузки.
    final forceNew =
        sessionsWithoutNew >= rules.sessionsWithoutNewBeforeForcing;

    if (overloaded && !forceNew) {
      return LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: review,
        reason: 'нагрузка $load > $loadThreshold',
      );
    }

    if (available.isEmpty) {
      return LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: review,
        reason: 'в графе нет доступных атомов',
      );
    }

    // 4. Обычный ввод.
    final newAtoms = forceNew && overloaded
        ? available.take(1).toList()
        : _pickNew(available, ctx);

    return LessonPlan(
      template: _templateFor(newAtoms.first),
      newAtoms: newAtoms,
      reviewAtoms: review,
      reason: forceNew && overloaded
          ? 'гарантия темпа: $sessionsWithoutNew сессий без новых'
          : 'обычный ввод',
    );
  }

  /// Что вводим этим уроком.
  ///
  /// Обычно два атома. Но в начале курса спрашивать не из чего: задания
  /// строятся выбором из введённых атомов, и с одной буквой урок выходит
  /// вчетверо короче обещанного. Пока пул мал, берём больше — ровно столько,
  /// чтобы набралась полная сессия.
  ///
  /// Понятия в счёт не идут: их объясняют, а не спрашивают, и пул вариантов
  /// они не пополняют. Взять их урок всё равно может — просто сверх лимита.
  List<Atom> _pickNew(List<Atom> available, CurriculumContext ctx) {
    final target = _newAtomCount(ctx);
    final picked = <Atom>[];
    var drillable = 0;

    for (final atom in available) {
      if (drillable >= target) break;
      picked.add(atom);
      if (atom.kind != AtomKind.concept) drillable++;
    }
    return picked;
  }

  int _newAtomCount(CurriculumContext ctx) {
    // Считаем только то, что можно спросить заданием: понятия объясняются
    // и в закрепление не идут, поэтому пул вариантов ими не пополняется.
    final drillable = curriculum.nodes
        .where(
          (n) =>
              n.atom.kind != AtomKind.concept &&
              ctx.stateOf(n.atom.id) != AtomState.fresh,
        )
        .length;
    if (drillable >= _minAtomsForFullSession) return _newAtomsPerLesson;

    return max(_newAtomsPerLesson, _minAtomsForFullSession - drillable);
  }

  /// Сколько атомов нужно, чтобы сессия набралась целиком.
  int get _minAtomsForFullSession =>
      (rules.tasksPerSession / _maxDrillsPerAtom).ceil();

  static const _newAtomsPerLesson = 2;

  /// Держится в паре с потолком повторов у генератора.
  static const _maxDrillsPerAtom = 3;

  LessonTemplate _templateFor(Atom atom) => switch (atom.kind) {
    AtomKind.concept => LessonTemplate.concept,
    AtomKind.syllable => LessonTemplate.connection,
    _ => LessonTemplate.newLetter,
  };

  /// Отложенные в нагрузку не входят — в этом и смысл откладывания.
  int _load(CurriculumContext ctx, int sessionId) => ctx.progress.entries
      .where(
        (e) =>
            e.value.state == AtomState.learning &&
            !e.value.isDeferredAt(sessionId, rules),
      )
      .length;

  List<String> _deferred(CurriculumContext ctx, int sessionId) => ctx
      .progress
      .entries
      .where((e) => e.value.isDeferredAt(sessionId, rules))
      .map((e) => e.key)
      .toList();

  String? _oldestDeferred(CurriculumContext ctx, List<String> deferred) =>
      deferred
          .sortedBy<num>((id) => ctx.progress[id]!.deferredAtSession ?? 0)
          .firstOrNull;

  List<String> _reviewQueue(CurriculumContext ctx, int sessionId) =>
      ReviewQueue(rules: rules).build(ctx, sessionId: sessionId);
}
