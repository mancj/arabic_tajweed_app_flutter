import 'dart:math';
import 'package:collection/collection.dart';

import 'atom.dart';
import 'curriculum.dart';

/// Проверяем недостающие зависимости выбранной темы. Для далёкой темы
/// берём короткую выборку: безошибочный результат подтверждает и остальное
/// как weak, а частичный успех подтверждает только проверенные элементы.
class KnowledgeCheck {
  KnowledgeCheck({
    required this.curriculum,
    required this.topic,
    required this.context,
    Random? random,
  }) : _random = random ?? Random() {
    _addPreviousTopics();
    _require(topic.requirement);
    final missing = atoms.where((a) => a.kind != AtomKind.concept).toList();
    checkedAtoms = missing.length <= maxCheckedAtoms
        ? missing
        : _sample(missing);
    inferredAtoms = missing.where((a) => !checkedAtoms.contains(a)).toList();
    questions = [
      for (final atom in checkedAtoms)
        for (final reverse in [false, true]) _question(atom, reverse),
    ];
  }

  /// Двадцать вопросов сопоставимы с обычным занятием и помещаются в один
  /// короткий экзамен даже при переходе через весь алфавит.
  static const maxCheckedAtoms = 10;

  final Curriculum curriculum;
  final Topic topic;
  final CurriculumContext context;
  final Random _random;
  final List<Atom> atoms = [];
  final Set<String> _visited = {};
  late final List<Atom> checkedAtoms;
  late final List<Atom> inferredAtoms;
  late final List<KnowledgeQuestion> questions;
  bool get isCondensed => inferredAtoms.isNotEmpty;
  List<Atom> get concepts =>
      atoms.where((a) => a.kind == AtomKind.concept).toList();

  List<Atom> get knowledgeAtoms =>
      atoms.where((a) => a.kind != AtomKind.concept).toList();

  /// Переход к выбранной теме закрывает весь путь до неё, а не только
  /// минимальные зависимости графа.
  void _addPreviousTopics() {
    final targetIndex = curriculum.topics.indexWhere((t) => t.id == topic.id);
    if (targetIndex < 0) {
      throw StateError('Тема ${topic.id} отсутствует в программе курса');
    }
    for (final previous in curriculum.topics.take(targetIndex)) {
      for (final id in previous.counterOf) {
        if (!context.isKnown(id)) _add(id);
      }
    }
  }

  void _require(Requirement requirement) {
    if (requirement.isMet(context)) return;
    switch (requirement) {
      case Always():
        break;
      case AtomKnown(:final atomId):
        _add(atomId);
      case AtomIntroducedReq(:final atomId):
        _add(atomId);
      case AllOf(:final parts):
        for (final part in parts) {
          _require(part);
        }
      case LettersKnown(:final count):
        final needed = count - context.knownLetterCount;
        final candidates = curriculum.formsByLetter.entries
            .where((e) => !context.isLetterKnown(e.key))
            .sorted(
              (a, b) => b.value
                  .where(context.isKnown)
                  .length
                  .compareTo(a.value.where(context.isKnown).length),
            );
        for (final letter in candidates.take(needed)) {
          for (final id in letter.value) {
            if (!context.isKnown(id)) _add(id);
          }
        }
      case TopicOpen(:final topicId):
        final prior = curriculum.topics.firstWhere((t) => t.id == topicId);
        _require(prior.requirement);
        for (final id in prior.counterOf) {
          if (!context.isKnown(id)) _add(id);
        }
    }
  }

  void _add(String id) {
    if (!_visited.add(id)) return;
    final node = curriculum.nodes.firstWhere((n) => n.atom.id == id);
    _require(node.requirement);
    atoms.add(node.atom);
  }

  List<Atom> _sample(List<Atom> missing) {
    // В выборку попадают разные виды материала и разные формы букв.
    // Перемешивание внутри группы не закрепляет одни и те же буквы за тестом.
    final groups = missing.groupListsBy(
      (atom) => switch (atom.kind) {
        AtomKind.letterForm => 'letter.${atom.form?.name}',
        AtomKind.syllable =>
          atom.audioAsset == null ? 'connection' : 'vocalized',
        _ => atom.kind.name,
      },
    );
    for (final group in groups.values) {
      group.shuffle(_random);
    }
    final selected = <Atom>[];
    while (selected.length < maxCheckedAtoms) {
      var added = false;
      for (final group in groups.values) {
        if (group.isEmpty) continue;
        selected.add(group.removeLast());
        added = true;
        if (selected.length == maxCheckedAtoms) break;
      }
      if (!added) break;
    }
    selected.shuffle(_random);
    return selected;
  }

  KnowledgeQuestion _question(Atom atom, bool reverse) {
    final others =
        curriculum.nodes
            .map((n) => n.atom)
            .where(
              (a) =>
                  a.id != atom.id &&
                  a.kind == atom.kind &&
                  a.form == atom.form &&
                  (atom.kind == AtomKind.word || a.label != atom.label) &&
                  a.display != atom.display,
            )
            .toList()
          ..shuffle(_random);
    final choices = [atom, ...others.take(2)]..shuffle(_random);
    if (choices.length < 2) {
      throw StateError('Нет вариантов проверки для ${atom.id}');
    }
    return KnowledgeQuestion(
      atom: atom,
      options: choices,
      reverse: reverse,
      answerIndex: choices.indexOf(atom),
    );
  }
}

class KnowledgeQuestion {
  const KnowledgeQuestion({
    required this.atom,
    required this.options,
    required this.reverse,
    required this.answerIndex,
  });
  final Atom atom;
  final List<Atom> options;
  final bool reverse;
  final int answerIndex;
}
