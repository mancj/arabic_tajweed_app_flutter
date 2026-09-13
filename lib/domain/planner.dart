import 'dart:math';

import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'learning_rules.dart';
import 'review_queue.dart';
import 'topic_board.dart';

/// Шаблон урока. Не «урок 7», а урок такого типа. См. SPEC.md §6.2.
enum LessonTemplate { concept, newLetter, review, connection }

class LessonPlan {
  const LessonPlan({
    required this.template,
    required this.newAtoms,
    required this.reviewAtoms,
    required this.reason,
    this.spacedReview = const [],
    this.topicId,
    this.reviewCounts = const {},
  });

  /// Небольшой цельный блок материала; оглавление может объединять их.
  final String? topicId;
  final LessonTemplate template;
  final List<Atom> newAtoms;

  /// Атомы урока, которые уже знакомы: они идут в закрепление вместе с новыми.
  final List<String> reviewAtoms;

  /// Короткое закрепление пробелов: точное число встреч с каждым атомом.
  /// Пусто у знакомства с новым материалом и полного повтора выбранной темы.
  final Map<String, int> reviewCounts;
  bool get isFocusedReview => reviewCounts.isNotEmpty;

  /// Возврат старого из общей очереди — блок «повтор» по ТЗ §6.2.
  /// Это буквы из других тем, иначе они не всплывали бы никогда.
  /// Кандидаты на оставшиеся места; обязательный материал — newAtoms/reviewAtoms.
  final List<String> spacedReview;

  /// Какое правило сработало. Нужно для отладки и аналитики: без этого
  /// невозможно понять, почему у пользователя третью сессию нет новых букв.
  final String reason;

  /// Проверяем до объяснений: генератор обязан спросить весь материал
  /// плана. Слишком большую тему нужно разделить в программе курса.
  int minimumTaskCount(Curriculum curriculum, LearningRules rules) {
    final own = _ownAtoms(curriculum);
    final narrowLetters = isNarrowBaseLetterBlock(curriculum);
    final minimum = own.values
        .map(
          (atom) =>
              reviewCounts[atom.id] ??
              (narrowLetters && atom.kind != AtomKind.concept
                  ? max(
                      rules.minimumExercises(atom),
                      rules.narrowLetterExercises,
                    )
                  : rules.minimumExercises(atom)),
        )
        .sum;
    return minimum;
  }

  /// Полный блок ровно из двух отдельных букв. Для него не нужны пятые
  /// встречи только ради общего бюджета: разнообразие даёт старый материал.
  bool isNarrowBaseLetterBlock(Curriculum curriculum) {
    if (isFocusedReview) return false;
    final drillable = _ownAtoms(
      curriculum,
    ).values.where((atom) => atom.kind != AtomKind.concept).toList();
    return drillable.length == 2 &&
        drillable.every(
          (atom) => atom.letterId != null && atom.form == LetterForm.isolated,
        );
  }

  Map<String, Atom> _ownAtoms(Curriculum curriculum) {
    final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
    return {
      for (final atom in newAtoms) atom.id: atom,
      for (final id in reviewAtoms)
        id:
            byId[id] ??
            (throw StateError('Неизвестный атом $id в плане урока')),
    };
  }

  void validate(Curriculum curriculum, LearningRules rules, {int? taskLimit}) {
    final minimum = minimumTaskCount(curriculum, rules);
    final limit = taskLimit ?? rules.tasksPerSession;
    final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
    final reserved = min(
      rules.reviewPerSession,
      spacedReview
          .map((id) => byId[id])
          .nonNulls
          .where((atom) => atom.kind != AtomKind.concept)
          .length,
    );
    if (minimum > limit) {
      throw StateError(
        'План «$reason» требует минимум $minimum заданий '
        'при лимите $limit. Разделите материал на уроки; '
        'пропускать формы нельзя.',
      );
    }
    // В коротком остатке сессии возврат старого может сжаться:
    // цельный новый материал важнее резерва повторения.
    if (taskLimit == null && minimum + reserved > limit) {
      throw StateError(
        'План «$reason» требует минимум ${minimum + reserved} заданий '
        'при лимите $limit. Разделите материал на уроки; '
        'пропускать формы нельзя.',
      );
    }
  }
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
    Set<String>? topicIds,
    Map<String, int> previousCounts = const {},
  }) {
    final deferred = _deferred(ctx, sessionId);
    final review = _reviewQueue(
      ctx,
      sessionId,
    ).where((id) => (previousCounts[id] ?? 0) < _maxDrillsPerAtom).toList();

    // 1. Потолок отложенных. Предохранитель на предохранитель: иначе
    //    человек формально не застревает, а фактически ничего не учит.
    if (deferred.length > rules.maxDeferred) {
      final revived = _oldestDeferred(ctx, deferred);
      return _buildPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        // Досрочный возврат обязателен: иначе отложенные ждут своей паузы,
        // а урок-повторение работает вхолостую.
        reviewAtoms: [if (revived != null) revived, ...review],
        reason: 'отложенных ${deferred.length} > ${rules.maxDeferred}',
      );
    }

    if (curriculum.topics.isNotEmpty) {
      return _planByTopics(
        ctx,
        sessionId,
        sessionsWithoutNew,
        review,
        topicIds,
        previousCounts,
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
      return _buildPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: review,
        reason: 'нагрузка $load > $loadThreshold',
      );
    }

    if (available.isEmpty) {
      return _buildPlan(
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

    return _buildPlan(
      template: _templateFor(newAtoms.first),
      newAtoms: newAtoms,
      reviewAtoms: review,
      reason: forceNew && overloaded
          ? 'гарантия темпа: $sessionsWithoutNew сессий без новых'
          : 'обычный ввод',
    );
  }

  /// Заполнение остатка сессии, когда цельный новый блок уже не
  /// помещается. Сначала берём то, что пора повторить, затем любой
  /// знакомый материал. Новых атомов этот план не вводит.
  LessonPlan practicePlan({
    required CurriculumContext ctx,
    required int sessionId,
    required int taskLimit,
    Map<String, int> previousCounts = const {},
    Set<String>? atomIds,
  }) {
    final due = _reviewQueue(
      ctx,
      sessionId,
    ).where((id) => atomIds == null || atomIds.contains(id));
    final familiar = curriculum.nodes
        .where(
          (node) =>
              node.atom.kind != AtomKind.concept &&
              (atomIds == null || atomIds.contains(node.atom.id)) &&
              ctx.stateOf(node.atom.id) != AtomState.fresh &&
              !(ctx.progress[node.atom.id]?.isDeferredAt(sessionId, rules) ??
                  false),
        )
        .map((node) => node.atom.id);
    final candidates = {
      ...due,
      ...familiar,
    }.where((id) => (previousCounts[id] ?? 0) < _maxDrillsPerAtom);
    final counts = <String, int>{};
    var remaining = taskLimit;
    while (remaining > 0) {
      var added = false;
      for (final id in candidates) {
        final available =
            _maxDrillsPerAtom - (previousCounts[id] ?? 0) - (counts[id] ?? 0);
        if (available <= 0) continue;
        counts.update(id, (count) => count + 1, ifAbsent: () => 1);
        remaining--;
        added = true;
        if (remaining == 0) break;
      }
      if (!added) break;
    }
    final plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: counts.keys.toList(),
      reviewCounts: counts,
      reason: 'заполняем остаток занятия',
    );
    plan.validate(curriculum, rules, taskLimit: taskLimit);
    return plan;
  }

  LessonPlan _planByTopics(
    CurriculumContext ctx,
    int sessionId,
    int sessionsWithoutNew,
    List<String> review,
    Set<String>? topicIds,
    Map<String, int> previousCounts,
  ) {
    final board = TopicBoard(curriculum, rules: rules);
    final ordered = board
        .statuses(ctx)
        .where((s) => topicIds == null || topicIds.contains(s.topic.id))
        .toList();
    // Оглавление — это программа курса, а не просто витрина. Даже если
    // широкое условие более поздней темы уже выполнено, она не обгоняет
    // первую незавершённую тему. Так следующий модуль не начинается до
    // завершения предыдущего.
    final frontier = ordered.firstWhereOrNull((s) => !s.isDone);
    final candidate =
        frontier != null &&
            frontier.canPractice &&
            // Пауза после серии ошибок остаётся паузой: вместо перехода
            // вперёд даём доступное повторение до окончания паузы.
            !frontier.topic.counterOf.any(
              (id) => ctx.progress[id]?.isDeferredAt(sessionId, rules) ?? false,
            )
        ? frontier
        : null;
    // Просмотр карточки и несколько ответов ещё не завершают материал.
    // Продолжаем начатый блок по знаниям, без сохранения очереди занятия.
    // Гарантия темпа не позволяет перескочить обязательную практику.
    final unfinished = candidate?.started == true ? candidate : null;
    if (unfinished != null) {
      if (unfinished.topic.counterOf.every(
        (id) => ctx.stateOf(id) != AtomState.fresh,
      )) {
        final focused = _focusOnGaps(
          unfinished.topic,
          board,
          ctx,
          previousCounts,
        );
        if (focused != null) return focused;
      } else {
        return board.planFor(
          unfinished.topic,
          ctx,
          sessionId: sessionId,
          rules: rules,
        );
      }
    }
    final next =
        candidate != null &&
            candidate.topic.counterOf.any(
              (id) => ctx.stateOf(id) == AtomState.fresh,
            )
        ? candidate
        : null;
    final overloaded = _load(ctx, sessionId) > loadThreshold;
    final force = sessionsWithoutNew >= rules.sessionsWithoutNewBeforeForcing;
    if (next != null && (!overloaded || force)) {
      // Весь объявленный блок обязателен, включая все формы. Если он не
      // помещается, исправляется контент; генератор ничего не отбрасывает.
      return board.planFor(next.topic, ctx, sessionId: sessionId, rules: rules);
    }
    final scope = topicIds == null
        ? null
        : curriculum.topics
              .where((t) => topicIds.contains(t.id))
              .expand((t) => t.counterOf)
              .toSet();
    final due = review
        .where((id) => scope == null || scope.contains(id))
        .toList();
    // «Потренироваться» работает и до срока очередного повторения.
    final familiar = curriculum.nodes
        .where(
          (n) =>
              n.atom.kind != AtomKind.concept &&
              ctx.stateOf(n.atom.id) != AtomState.fresh &&
              (previousCounts[n.atom.id] ?? 0) < _maxDrillsPerAtom &&
              !(ctx.progress[n.atom.id]?.isDeferredAt(sessionId, rules) ??
                  false) &&
              (scope == null || scope.contains(n.atom.id)),
        )
        .map((n) => n.atom.id);
    return _buildPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: due.isNotEmpty ? due : familiar.toList(),
      reason: overloaded
          ? 'закрепление перед новым материалом'
          : 'повторение знакомого',
    );
  }

  LessonPlan? _focusOnGaps(
    Topic topic,
    TopicBoard board,
    CurriculumContext ctx,
    Map<String, int> previousCounts,
  ) {
    final counts = <String, int>{};
    var remaining = min(rules.focusedReviewTasks, rules.tasksPerSession);
    final gaps = topic.counterOf
        .where((id) => !board.isDone(id, ctx))
        .sortedBy<num>((id) => ctx.progress[id]?.lastSeenSession ?? 0);
    for (final id in gaps) {
      final atom = curriculum.nodes.firstWhere((n) => n.atom.id == id).atom;
      final p = ctx.progress[id]!;
      final missing = p.weak
          ? 0
          : rules
                .requiredPracticeModes(atom)
                .difference(p.successfulModes)
                .length;
      // Две встречи позволяют проверить разные умения. Когда знание уже
      // подтверждено, достаточно только пропущенного обязательного режима.
      final count = max(
        missing,
        ctx.isKnown(id) ? 0 : max(2, rules.cleanStreakForKnown - p.cleanStreak),
      );
      final available = min(
        remaining,
        _maxDrillsPerAtom - (previousCounts[id] ?? 0),
      );
      final scheduled = min(count, available);
      if (scheduled <= 0) continue;
      counts[id] = scheduled;
      remaining -= scheduled;
    }
    if (counts.isEmpty) return null;
    final plan = LessonPlan(
      topicId: topic.id,
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: counts.keys.toList(),
      reviewCounts: counts,
      reason: 'короткое закрепление пробелов в «${topic.title}»',
    );
    plan.validate(curriculum, rules);
    return plan;
  }

  /// Общая очередь — кандидаты, а не обещанный материал урока. Выбираем
  /// посильный набор до показа объяснений, затем весь план обязателен.
  LessonPlan _buildPlan({
    required LessonTemplate template,
    required List<Atom> newAtoms,
    required List<String> reviewAtoms,
    required String reason,
    int? taskLimit,
  }) {
    final limit = taskLimit ?? rules.tasksPerSession;
    var remaining = limit - newAtoms.map(rules.minimumExercises).sum;
    final selected = <String>[];
    final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
    for (final id in reviewAtoms.toSet()) {
      final atom = byId[id];
      if (atom == null || newAtoms.any((a) => a.id == id)) continue;
      final minimum = rules.minimumExercises(atom);
      if (minimum > remaining) continue;
      selected.add(id);
      remaining -= minimum;
    }
    final plan = LessonPlan(
      template: template,
      newAtoms: newAtoms,
      reviewAtoms: selected,
      reason: reason,
    );
    plan.validate(curriculum, rules, taskLimit: taskLimit);
    return plan;
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
  static const _maxDrillsPerAtom = 5;

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
      ReviewQueue(
        rules: rules,
      ).build(ctx, sessionId: sessionId, curriculum: curriculum);
}
