import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'learning_rules.dart';
import 'planner.dart';
import 'review_queue.dart';

/// Состояние блока материала в «Моём пути». Освоенность считается по
/// знаниям; завершённое занятие само по себе не даёт галочку.
enum TopicState {
  /// Условие графа не выполнено — замок и текст условия.
  locked,

  /// Открыт, но человек его ещё не начинал.
  available,

  /// Блок, выбранный для ближайшего занятия.
  current,

  /// Материал уже изучается, но ещё требует закрепления.
  unfinished,

  /// Не проходили — сдали тест «Уже знаю». Атомы помечены weak.
  passedByTest,

  /// Все элементы блока освоены.
  done,
}

/// Тема со счётчиком и человекочитаемым условием.
class TopicStatus {
  const TopicStatus({
    required this.topic,
    required this.state,
    required this.done,
    required this.total,
    required this.hint,
    required this.canPractice,
    required this.started,
  });

  /// Галочка относится к знаниям, а не к количеству занятий.
  bool get isDone =>
      state == TopicState.done || state == TopicState.passedByTest;

  bool get showsMastery => state != TopicState.locked;

  final Topic topic;
  final TopicState state;

  /// Сколько атомов темы освоено из скольких. У темы без счётчика — 0 из 0.
  final int done;
  final int total;

  /// Чего не хватает для открытия. Пусто у открытых тем.
  final String hint;

  /// Хоть один атом темы уже показывали. Отличает «начать» от «продолжить».
  final bool started;

  /// По теме можно постучать и повторить её. Закрытая только показывает
  /// условие; открытая, где ещё нечего повторять, тоже не реагирует.
  final bool canPractice;

  bool get hasCounter => total > 0;
  double get progress => total == 0 ? 0 : done / total;
}

/// Список тем для главного экрана. Он и есть замена списку уроков:
/// уроки генерируются, а понятия известны заранее. См. SPEC.md §8.
class TopicBoard {
  const TopicBoard(this.curriculum);

  final Curriculum curriculum;

  /// [completed] — id закрытых уроков и способ закрытия: true, если сдан
  /// тестом. [currentId] — урок, которым занимались последним.
  List<TopicStatus> statuses(
    CurriculumContext ctx, {
    Map<String, bool> completed = const {},
    String? currentId,
  }) => [
    for (final (index, topic) in curriculum.topics.indexed)
      _statusOf(topic, index, ctx, completed, currentId),
  ];

  TopicStatus _statusOf(
    Topic topic,
    int index,
    CurriculumContext ctx,
    Map<String, bool> completed,
    String? currentId,
  ) {
    final done = topic.counterOf.where((id) => isDone(id, ctx)).length;
    final total = topic.counterOf.length;
    final started = topic.counterOf.any(
      (id) => ctx.stateOf(id) != AtomState.fresh,
    );
    // Старые отметки сохраняют доступ, но не подменяют знание материала.
    final previous = index == 0 ? null : curriculum.topics[index - 1];
    final open =
        topic.requirement.isMet(ctx.accessContext) ||
        started ||
        completed.containsKey(topic.id) ||
        (previous != null && completed.containsKey(previous.id));
    final state = !open
        ? TopicState.locked
        : total > 0 && done == total
        ? TopicState.done
        : topic.id == currentId
        ? TopicState.current
        : started
        ? TopicState.unfinished
        : TopicState.available;

    return TopicStatus(
      topic: topic,
      state: state,
      done: done,
      total: total,
      hint: state == TopicState.locked
          ? missingHint(topic.requirement, ctx.accessContext)
          : '',
      started: started,
      canPractice: open && topic.counterOf.every((id) => _practicable(id, ctx)),
    );
  }

  /// Урок по конкретной теме. Планировщик тут не участвует: он решает,
  /// что вводить дальше по всему курсу, а здесь набор атомов задан темой.
  ///
  /// Незнакомые атомы темы вводятся, знакомые повторяются. Так нажатие
  /// по строке всегда работает с той темой, на которую нажали, а не уводит
  /// туда, куда как раз собирался планировщик.
  LessonPlan planFor(
    Topic topic,
    CurriculumContext ctx, {
    int sessionId = 1,
    LearningRules rules = const LearningRules(),
  }) {
    final nodes = topic.counterOf
        .map(
          (id) =>
              _node(id) ??
              (throw StateError('В теме ${topic.id} неизвестный атом $id')),
        )
        .toList();

    // Вся тема обязательна. Если часть материала пока недоступна,
    // нужно исправить зависимости или разделить тему, а не урезать урок.
    final fresh = nodes
        .where((n) => ctx.stateOf(n.atom.id) == AtomState.fresh)
        .map((n) => n.atom)
        .toList();
    final blocked = nodes.where(
      (n) =>
          ctx.stateOf(n.atom.id) == AtomState.fresh &&
          !n.requirement.isMet(ctx.accessContext),
    );
    if (blocked.isNotEmpty) {
      throw StateError(
        'Тема ${topic.id} недоступна целиком: '
        '${blocked.map((n) => n.atom.id).join(', ')}. '
        'Проверьте порядок уроков и зависимости.',
      );
    }

    final known = topic.counterOf
        .where((id) => ctx.stateOf(id) != AtomState.fresh)
        .toList();

    // Блок повтора берётся из общей очереди, а не из самой темы: иначе
    // буквы прошлых уроков не возвращались бы никогда. См. ТЗ §6.2.
    //
    // Но только назад: атомы тем, которые идут после этой, исключаются.
    // Иначе возврат к пройденному уроку тащит буквы из следующего —
    // начатого и брошенного, — и повторение выглядит как чужой урок.
    final spaced = ReviewQueue(rules: rules).build(
      ctx,
      sessionId: sessionId,
      exclude: {...topic.counterOf, ..._atomsAfter(topic)},
      curriculum: curriculum,
    );

    final plan = LessonPlan(
      topicId: topic.id,
      template: fresh.isEmpty
          ? LessonTemplate.review
          : LessonTemplate.newLetter,
      newAtoms: fresh,
      reviewAtoms: known,
      spacedReview: spaced,
      reason: fresh.isEmpty
          ? 'повторение темы «${topic.title}»'
          : 'тема «${topic.title}»',
    );
    plan.validate(curriculum, rules);
    return plan;
  }

  /// Атомы тем, стоящих в списке после [topic]. Тема, которой нет
  /// в списке, ничего не отсекает.
  Set<String> _atomsAfter(Topic topic) {
    final index = curriculum.topics.indexWhere((t) => t.id == topic.id);
    if (index < 0) return const {};
    return {
      for (final later in curriculum.topics.skip(index + 1)) ...later.counterOf,
    };
  }

  /// Есть ли по теме что показать: либо готовый к вводу атом, либо уже
  /// знакомый — его можно повторить. Понятие перечитывается когда угодно.
  bool _practicable(String atomId, CurriculumContext ctx) {
    final node = _node(atomId);
    if (node == null) return false;
    if (ctx.stateOf(atomId) != AtomState.fresh) return true;
    return node.requirement.isMet(ctx.accessContext);
  }

  CurriculumNode? _node(String atomId) =>
      curriculum.nodes.firstWhereOrNull((n) => n.atom.id == atomId);

  /// Понятие считается пройденным, как только его объяснили: спросить его
  /// заданием нельзя, поэтому до known оно не доходит никогда.
  bool isDone(String atomId, CurriculumContext ctx) {
    final atom = _atom(atomId);
    final state = ctx.stateOf(atomId);
    return atom?.kind == AtomKind.concept
        ? state.index >= AtomState.introduced.index
        : state.index >= AtomState.known.index;
  }

  String missingHint(Requirement requirement, CurriculumContext ctx) {
    List<Requirement> missing(Requirement r) => r.isMet(ctx)
        ? []
        : switch (r) {
            AllOf(:final parts) => parts.expand(missing).toList(),
            _ => [r],
          };
    final parts = missing(requirement);
    final ids = parts.whereType<AtomKnown>().map((r) => r.atomId).toSet();
    if (ids.isNotEmpty) {
      if (ids.length <= 3) {
        return 'нужно освоить: ${ids.map(_label).join(', ')}';
      }
      final bases = ids.every((id) => _atom(id)?.form == LetterForm.isolated);
      return bases
          ? 'нужно освоить ещё ${ids.length} ${_letters(ids.length)}'
          : 'нужно закрепить ещё ${ids.length} форм';
    }
    return parts.map(describe).where((s) => s.isNotEmpty).toSet().join(', ');
  }

  /// Условие словами. Замок должен объяснять себя: «нужно 8 букв» — это
  /// ребро графа, отрендеренное текстом, а не произвольная витрина.
  String describe(Requirement requirement) => switch (requirement) {
    Always() => '',
    AtomKnown(:final atomId) => 'нужно освоить ${_label(atomId)}',
    AtomIntroducedReq(:final atomId) => 'после знакомства с ${_label(atomId)}',
    LettersKnown(:final count) => 'нужно $count ${_letters(count)}',
    TopicOpen(:final topicId) => 'после «${_topic(topicId)}»',
    AllOf(:final parts) =>
      parts.map(describe).where((s) => s.isNotEmpty).join(', '),
  };

  String _label(String atomId) => _atom(atomId)?.label ?? atomId;

  String _topic(String id) =>
      curriculum.topics.firstWhereOrNull((m) => m.id == id)?.title ?? id;

  Atom? _atom(String atomId) => _node(atomId)?.atom;

  static String _letters(int count) {
    final tail = count % 100;
    if (tail >= 11 && tail <= 14) return 'букв';
    return switch (count % 10) {
      1 => 'букву',
      2 || 3 || 4 => 'буквы',
      _ => 'букв',
    };
  }
}
