import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'planner.dart';

/// Как урок выглядит в списке курса.
///
/// «Пройден» — это факт о занятии, а не о знании: человек дошёл до конца
/// сессии. Освоенность букв добирается повторениями и на галочку не влияет.
/// Раньше их считали одним числом, и закрытый урок выглядел недоделанным.
enum TopicState {
  /// Условие графа не выполнено — замок и текст условия.
  locked,

  /// Открыт, но человек его ещё не начинал.
  available,

  /// Урок, которым занимались последним. К нему ведёт «Продолжить».
  current,

  /// Начат и брошен: человек ушёл вперёд, не закрыв этот.
  unfinished,

  /// Не проходили — сдали тест «Уже знаю». Атомы помечены weak.
  passedByTest,

  /// Дошёл до конца сессии.
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

  /// Показывать ли полосу освоенности. У закрытых уроков её прячем:
  /// урок закончен, и напоминать о недобранных повторах незачем.
  /// Урок закрыт — пройден или зачтён тестом.
  bool get isDone =>
      state == TopicState.done || state == TopicState.passedByTest;

  bool get showsMastery =>
      state == TopicState.current || state == TopicState.unfinished;

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
  }) => curriculum.topics
      .map((t) => _statusOf(t, ctx, completed, currentId))
      .toList();

  TopicStatus _statusOf(
    Topic topic,
    CurriculumContext ctx,
    Map<String, bool> completed,
    String? currentId,
  ) {
    final done = topic.counterOf.where((id) => isDone(id, ctx)).length;
    final total = topic.counterOf.length;
    final open = topic.requirement.isMet(ctx);
    final started = topic.counterOf.any(
      (id) => ctx.stateOf(id) != AtomState.fresh,
    );

    final state = switch (completed[topic.id]) {
      true => TopicState.passedByTest,
      false => TopicState.done,
      // Не закрыт: текущий, брошенный или ещё не начатый.
      null when !open => TopicState.locked,
      null when topic.id == currentId => TopicState.current,
      null when started => TopicState.unfinished,
      null => TopicState.available,
    };

    return TopicStatus(
      topic: topic,
      state: state,
      done: done,
      total: total,
      hint: state == TopicState.locked ? describe(topic.requirement) : '',
      started: started,
      canPractice:
          state != TopicState.locked &&
          topic.counterOf.any((id) => _practicable(id, ctx)),
    );
  }

  /// Урок по конкретной теме. Планировщик тут не участвует: он решает,
  /// что вводить дальше по всему курсу, а здесь набор атомов задан темой.
  ///
  /// Незнакомые атомы темы вводятся, знакомые повторяются. Так нажатие
  /// по строке всегда работает с той темой, на которую нажали, а не уводит
  /// туда, куда как раз собирался планировщик.
  LessonPlan planFor(Topic topic, CurriculumContext ctx) {
    final nodes = topic.counterOf.map((id) => _node(id)).nonNulls.toList();

    // Вводим только то, что граф уже разрешил: у темы могут быть атомы,
    // до которых человек ещё не дошёл.
    final fresh = nodes
        .where(
          (n) =>
              ctx.stateOf(n.atom.id) == AtomState.fresh &&
              n.requirement.isMet(ctx),
        )
        .map((n) => n.atom)
        .toList();

    final known = topic.counterOf
        .where((id) => ctx.stateOf(id) != AtomState.fresh)
        .toList();

    return LessonPlan(
      template: fresh.isEmpty
          ? LessonTemplate.consolidation
          : LessonTemplate.newLetter,
      newAtoms: fresh,
      reviewAtoms: known,
      reason: fresh.isEmpty
          ? 'повторение темы «${topic.title}»'
          : 'тема «${topic.title}»',
    );
  }

  /// Есть ли по теме что показать: либо готовый к вводу атом, либо уже
  /// знакомый — его можно повторить. Понятие перечитывается когда угодно.
  bool _practicable(String atomId, CurriculumContext ctx) {
    final node = _node(atomId);
    if (node == null) return false;
    if (node.atom.kind == AtomKind.concept) return true;
    if (ctx.stateOf(atomId) != AtomState.fresh) return true;
    return node.requirement.isMet(ctx);
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
