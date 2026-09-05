import 'package:json_annotation/json_annotation.dart';

part 'atom.g.dart';

/// Единица обучения. Не буква, а сочетание буквы и формы — либо знак,
/// слог или понятие. Прогресс, очередь повторений и разблокировки
/// считаются по атомам. См. SPEC.md §2.
enum AtomKind {
  /// Буква в конкретной форме: ب-изолированная, ـبـ-средняя.
  letterForm,

  /// Огласовка как знак: фатха, касра, дамма. Три штуки на весь курс.
  haraka,

  /// Прочие знаки чтения: сукун, шадда, мадд-алиф, мадд-вав, мадд-йа.
  sign,

  /// Сочетание «буква + знак». Создаётся лениво, при первой встрече
  /// в задании, а не заводится заранее — иначе комбинаторика взрывается.
  syllable,

  /// Понятие: точки, соединение, огласовки. Совпадает с темой.
  concept,
}

/// Формы буквы. У букв ا د ذ ر ز و есть только isolated и finalForm —
/// они не соединяются со следующей буквой.
enum LetterForm { isolated, initial, medial, finalForm }

/// Разбирается из ассетов, поэтому сериализуемо.
@JsonSerializable()
class Atom {
  const Atom({
    required this.id,
    required this.kind,
    required this.display,
    this.label = '',
    this.note = '',
    this.letterId,
    this.form,
    this.confusableWith = const [],
    this.tracing,
  });

  factory Atom.fromJson(Map<String, dynamic> json) => _$AtomFromJson(json);

  /// Стабильный идентификатор: 'ba.isolated', 'haraka.fatha', 'concept.dots'.
  final String id;
  final AtomKind kind;

  /// Что показывается пользователю: сам глиф или название понятия.
  final String display;

  /// Название словами: «Ба», «Точки». Нужно режимам, где спрашивают имя
  /// буквы, а не её начертание.
  final String label;

  /// Объяснение для блока «новое»: чем эта буква отличается от соседей.
  /// Пусто — показываем только глиф и название.
  final String note;

  final String? letterId;
  final LetterForm? form;

  /// Буквы, отличающиеся от этой одним признаком — обычно точками.
  /// Из них строится минимальная пара: ب / ت / ث. Задаётся в контенте,
  /// потому что это факт про арабское письмо, а не про код.
  final List<String> confusableWith;

  /// Имя SVG с осевыми линиями в `assets/svg/alphabet` — по нему строится
  /// фигура для обводки. Своё на каждую форму: `ba_base`, `ba_init`,
  /// `ba_mid`, `ba_end`. Атом без этого поля обводкой не спрашивается.
  final String? tracing;

  Map<String, dynamic> toJson() => _$AtomToJson(this);

  @override
  bool operator ==(Object other) => other is Atom && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Atom($id)';
}
