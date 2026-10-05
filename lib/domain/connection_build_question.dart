import 'package:collection/collection.dart';

import 'atom.dart';
import 'haraka_syllables.dart';

/// Одна недостающая буква в коротком соединении: форма и огласовка
/// выбираются отдельно. Остальные части уже собраны.
class ConnectionBuildQuestion {
  ConnectionBuildQuestion({
    required List<ConnectionBuildPart> parts,
    required this.missingIndex,
    required List<Atom> formOptions,
  }) : parts = List.unmodifiable(parts),
       formOptions = List.unmodifiable(formOptions);

  final List<ConnectionBuildPart> parts;
  final int missingIndex;
  final List<Atom> formOptions;

  ConnectionBuildPart get missingPart => parts[missingIndex];
  String get expectedFormId => missingPart.form.id;
  String get expectedMarkId => HarakaSyllables.markIdFor(missingPart.syllable);
  String get display => parts.map((part) => part.syllable.display).join();
  String get audioAsset => 'tts:$display';
  String get position => missingIndex == 0
      ? 'в начале'
      : missingIndex == parts.length - 1
      ? 'в конце'
      : 'в середине';

  List<String?> preview(String? formId, String? markId) => [
    for (final (index, part) in parts.indexed)
      if (index == missingIndex)
        switch (formOptions.firstWhereOrNull((form) => form.id == formId)) {
          final form? => _fixedFormGlyph(form, markId),
          null => null,
        }
      else
        _fixedFormGlyph(part.form, HarakaSyllables.markIdFor(part.syllable)),
  ];

  ConnectionBuildEvaluation evaluate({
    required String formId,
    required String markId,
  }) => ConnectionBuildEvaluation(
    formCorrect: formId == expectedFormId,
    harakaCorrect: markId == expectedMarkId,
  );

  /// Задаём выбранное начертание явно. Между частями виджет ставит ZWNJ:
  /// обычное соединение текста иначе незаметно исправило бы ошибочную форму.
  static String _fixedFormGlyph(Atom form, String? markId) {
    final joinsBefore = switch (form.form) {
      LetterForm.medial || LetterForm.finalForm => true,
      _ => false,
    };
    final joinsAfter = switch (form.form) {
      LetterForm.initial || LetterForm.medial => true,
      _ => false,
    };
    final bare = form.display.replaceAll('ـ', '');
    final mark = HarakaSyllables.marks.firstWhereOrNull(
      (mark) => mark.id == markId,
    );
    return '${joinsBefore ? '\u200d' : ''}'
        '${mark == null ? bare : HarakaSyllables.applyMark(bare, mark)}'
        '${joinsAfter ? '\u200d' : ''}';
  }
}

class ConnectionBuildPart {
  const ConnectionBuildPart({required this.form, required this.syllable});

  final Atom form;
  final Atom syllable;
}

class ConnectionBuildEvaluation {
  const ConnectionBuildEvaluation({
    required this.formCorrect,
    required this.harakaCorrect,
  });

  final bool formCorrect;
  final bool harakaCorrect;
  bool get correct => formCorrect && harakaCorrect;
}
