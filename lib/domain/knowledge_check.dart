import 'dart:math';
import 'package:collection/collection.dart';

import 'atom.dart';
import 'curriculum.dart';

/// Проверяем именно недостающие зависимости выбранной темы. Каждый атом
/// проверяется в обе стороны; случайная удача в одном вопросе не даёт зачёт.
class KnowledgeCheck {
  KnowledgeCheck({
    required this.curriculum,
    required this.topic,
    required this.context,
    Random? random,
  }) : _random = random ?? Random() {
    _require(topic.requirement);
    questions = [
      for (final reverse in [false, true])
        for (final atom in atoms.where((a) => a.kind != AtomKind.concept))
          _question(atom, reverse),
    ];
  }

  final Curriculum curriculum;
  final Topic topic;
  final CurriculumContext context;
  final Random _random;
  final List<Atom> atoms = [];
  final Set<String> _visited = {};
  late final List<KnowledgeQuestion> questions;
  List<Atom> get concepts =>
      atoms.where((a) => a.kind == AtomKind.concept).toList();

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

  KnowledgeQuestion _question(Atom atom, bool reverse) {
    final others =
        curriculum.nodes
            .map((n) => n.atom)
            .where(
              (a) =>
                  a.id != atom.id &&
                  a.kind == atom.kind &&
                  a.form == atom.form &&
                  a.label != atom.label &&
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
