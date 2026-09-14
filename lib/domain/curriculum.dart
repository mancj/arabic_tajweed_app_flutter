import 'package:json_annotation/json_annotation.dart';
import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';

part 'curriculum.g.dart';

/// Условие разблокировки — ребро графа знаний. Не «урок 7», а ограничение.
/// См. SPEC.md §6.1.
sealed class Requirement {
  const Requirement();

  bool isMet(CurriculumContext ctx);

  Map<String, dynamic> toJson();

  /// Разбор по дискриминатору `type`. Написан руками: иерархия голая
  /// `sealed` ради полиморфного `isMet`, а json_serializable такие
  /// не умеет без union-обёртки. См. CLAUDE.md.
  static Requirement fromJson(Map<String, dynamic> json) =>
      switch (json['type'] as String) {
        'always' => const Always(),
        'atomKnown' => AtomKnown(json['atomId'] as String),
        'atomIntroduced' => AtomIntroducedReq(json['atomId'] as String),
        'lettersKnown' => LettersKnown(json['count'] as int),
        'topicOpen' => TopicOpen(json['topicId'] as String),
        'allOf' => AllOf(
          (json['parts'] as List)
              .cast<Map<String, dynamic>>()
              .map(Requirement.fromJson)
              .toList(),
        ),
        final unknown => throw FormatException('неизвестный type: $unknown'),
      };
}

/// Конкретная зависимость: ث после ب и ت.
class AtomKnown extends Requirement {
  const AtomKnown(this.atomId);
  final String atomId;

  @override
  bool isMet(CurriculumContext ctx) => ctx.isKnown(atomId);

  @override
  Map<String, dynamic> toJson() => {'type': 'atomKnown', 'atomId': atomId};
}

/// Атом хотя бы показан пользователю. Нужно для тем вида
/// «правило про несоединяющиеся буквы» — оно появляется при вводе د.
class AtomIntroducedReq extends Requirement {
  const AtomIntroducedReq(this.atomId);
  final String atomId;

  @override
  bool isMet(CurriculumContext ctx) =>
      ctx.stateOf(atomId).index >= AtomState.introduced.index;

  @override
  Map<String, dynamic> toJson() => {'type': 'atomIntroduced', 'atomId': atomId};
}

/// Пороговое условие: «≥8 букв в known». Буква в known — это все её формы
/// в known, поэтому порог в 8 букв стоит 32 атомов.
class LettersKnown extends Requirement {
  const LettersKnown(this.count);
  final int count;

  @override
  bool isMet(CurriculumContext ctx) => ctx.knownLetterCount >= count;

  @override
  Map<String, dynamic> toJson() => {'type': 'lettersKnown', 'count': count};
}

class TopicOpen extends Requirement {
  const TopicOpen(this.topicId);
  final String topicId;

  @override
  bool isMet(CurriculumContext ctx) => ctx.isTopicOpen(topicId);

  @override
  Map<String, dynamic> toJson() => {'type': 'topicOpen', 'topicId': topicId};
}

class AllOf extends Requirement {
  const AllOf(this.parts);
  final List<Requirement> parts;

  @override
  bool isMet(CurriculumContext ctx) => parts.every((p) => p.isMet(ctx));

  @override
  Map<String, dynamic> toJson() => {
    'type': 'allOf',
    'parts': parts.map((p) => p.toJson()).toList(),
  };
}

/// Ничего не требует — стартовый узел.
class Always extends Requirement {
  const Always();

  @override
  bool isMet(CurriculumContext ctx) => true;

  @override
  Map<String, dynamic> toJson() => {'type': 'always'};
}

/// Тема: понятие, которое видит пользователь на главном экране.
/// Список конечен и известен заранее — в отличие от списка уроков.
/// См. SPEC.md §7а.
@JsonSerializable()
class Topic {
  const Topic({
    required this.id,
    required this.stage,
    required this.title,
    required this.requirement,
    this.counterOf = const [],
  });

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

  final String id;
  final int stage;
  final String title;

  @JsonKey(fromJson: Requirement.fromJson, toJson: _reqToJson)
  final Requirement requirement;

  /// Атомы, по которым считается прогресс темы («Хамза 2 из 5»).
  /// Пустой список — тема без счётчика.
  final List<String> counterOf;

  Map<String, dynamic> toJson() => _$TopicToJson(this);
}

/// Узел графа: атом плюс условие, при котором его можно вводить.
@JsonSerializable()
class CurriculumNode {
  const CurriculumNode({required this.atom, required this.requirement});

  factory CurriculumNode.fromJson(Map<String, dynamic> json) =>
      _$CurriculumNodeFromJson(json);

  final Atom atom;

  @JsonKey(fromJson: Requirement.fromJson, toJson: _reqToJson)
  final Requirement requirement;

  Map<String, dynamic> toJson() => _$CurriculumNodeToJson(this);
}

@JsonSerializable()
class Curriculum {
  const Curriculum({required this.nodes, required this.topics});

  factory Curriculum.fromJson(Map<String, dynamic> json) =>
      _$CurriculumFromJson(json);

  final List<CurriculumNode> nodes;
  final List<Topic> topics;

  Map<String, dynamic> toJson() => _$CurriculumToJson(this);

  /// Атомы, которые можно вводить прямо сейчас. Порядок в списке —
  /// порядок предпочтения планировщика.
  List<Atom> availableAtoms(CurriculumContext ctx) => nodes
      .where(
        (n) =>
            ctx.stateOf(n.atom.id) == AtomState.fresh &&
            n.requirement.isMet(ctx),
      )
      .map((n) => n.atom)
      .toList();

  Map<String, List<String>> get formsByLetter => groupBy(
    nodes.where((n) => n.atom.letterId != null && n.atom.form != null),
    (CurriculumNode n) => n.atom.letterId!,
  ).map((id, nodes) => MapEntry(id, nodes.map((n) => n.atom.id).toList()));

  Set<String> get letterFormIds => {
    for (final node in nodes)
      if (node.atom.kind == AtomKind.letterForm) node.atom.id,
  };

  List<Atom> get baseLetters => nodes
      .map((node) => node.atom)
      .where(
        (atom) =>
            atom.kind == AtomKind.letterForm &&
            atom.letterId != null &&
            atom.form == LetterForm.isolated,
      )
      .toList();

  Set<String> get baseLetterIds => baseLetters.map((atom) => atom.id).toSet();

  List<Topic> openTopics(CurriculumContext ctx) =>
      topics.where((m) => m.requirement.isMet(ctx)).toList();
}

/// Срез прогресса, по которому проверяются условия графа.
class CurriculumContext {
  CurriculumContext({required this.progress, required this.formsByLetter});

  final Map<String, AtomProgress> progress;

  /// letterId → id всех его форм. У ا د ذ ر ز و форм две, у остальных четыре.
  final Map<String, List<String>> formsByLetter;

  AtomState stateOf(String atomId) =>
      progress[atomId]?.state ?? AtomState.fresh;

  bool isKnown(String atomId) => stateOf(atomId).index >= AtomState.known.index;

  /// Буква считается освоенной, только когда освоены все её формы.
  bool isLetterKnown(String letterId) {
    final forms = formsByLetter[letterId];
    return forms != null && forms.isNotEmpty && forms.every(isKnown);
  }

  int get knownLetterCount => formsByLetter.keys.where(isLetterKnown).length;

  /// Доступ остаётся после ошибок: knownAt сохраняется при откате знания.
  CurriculumContext get accessContext => CurriculumContext(
    progress: progress.map(
      (id, p) => MapEntry(
        id,
        p.knownAt != null && p.state.index < AtomState.known.index
            ? p.copyWith(state: AtomState.known)
            : p,
      ),
    ),
    formsByLetter: formsByLetter,
  );

  final Set<String> _openTopics = {};

  bool isTopicOpen(String id) => _openTopics.contains(id);

  void markTopicOpen(String id) => _openTopics.add(id);
}

Map<String, dynamic> _reqToJson(Requirement r) => r.toJson();
