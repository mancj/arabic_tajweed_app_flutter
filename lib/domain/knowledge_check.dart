import 'dart:math';
import 'package:collection/collection.dart';

import 'atom.dart';
import 'curriculum.dart';
import 'exercise.dart';
import 'exercise_generator.dart';

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
    _generator = ExerciseGenerator(curriculum: curriculum, random: _random);
    _addPreviousTopics();
    _require(topic.requirement);
    final missing = atoms.where((a) => a.kind != AtomKind.concept).toList();
    // Формы хамзы здесь не спрашиваем: вопрос о названии её носителя
    // не соответствует заданию, с которым человек работает в курсе.
    final questionCandidates = missing.where(_canAskInCheck).toList();
    isCondensed = questionCandidates.length > maxCheckedAtoms;
    checkedAtoms = isCondensed
        ? _sample(questionCandidates)
        : questionCandidates;
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
  late final ExerciseGenerator _generator;
  final List<Atom> atoms = [];
  final Set<String> _visited = {};
  late final List<Atom> checkedAtoms;
  late final List<Atom> inferredAtoms;
  late final bool isCondensed;
  late final List<Exercise> questions;
  List<Atom> get concepts =>
      atoms.where((a) => a.kind == AtomKind.concept).toList();

  List<Atom> get knowledgeAtoms =>
      atoms.where((a) => a.kind != AtomKind.concept).toList();

  static bool _canAskInCheck(Atom atom) =>
      atom.kind != AtomKind.sign || atom.letterId != 'hamza';

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

  Exercise _question(Atom atom, bool reverse) {
    final eligibleIds = {
      for (final previous in curriculum.topics.take(
        curriculum.topics.indexWhere((t) => t.id == topic.id),
      ))
        ...previous.counterOf,
      for (final checked in atoms) checked.id,
      for (final id in context.progress.keys)
        if (context.isKnown(id)) id,
    };
    final pool = curriculum.nodes
        .map((n) => n.atom)
        .where((a) => eligibleIds.contains(a.id))
        .toList();
    final modes = ExerciseGenerator.choiceModesFor(atom);
    final exercise = _generator.choiceFor(
      atom: atom,
      mode: modes[reverse ? (modes.length - 1) : 0],
      pool: pool,
    );
    if (exercise.options.length < 2) {
      throw StateError('Нет вариантов проверки для ${atom.id}');
    }
    return exercise;
  }
}
