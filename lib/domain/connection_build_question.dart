import 'package:collection/collection.dart';

import 'atom.dart';
import 'connected_letter_glyph.dart';
import 'haraka_syllables.dart';

/// Одна недостающая буква в коротком соединении: форма и огласовка
/// выбираются отдельно. Остальные части уже собраны.
class ConnectionBuildQuestion {
  ConnectionBuildQuestion({
    required List<ConnectionBuildPart> parts,
    required this.missingIndex,
    required List<Atom> formOptions,
    this.contentId,
    String? audioAsset,
  }) : parts = List.unmodifiable(parts),
       formOptions = List.unmodifiable(formOptions),
       _audioAsset = audioAsset;

  final List<ConnectionBuildPart> parts;
  final int missingIndex;
  final List<Atom> formOptions;
  final String? contentId;
  final String? _audioAsset;

  ConnectionBuildPart get missingPart => parts[missingIndex];
  String get expectedFormId => missingPart.form.id;
  String get expectedMarkId => HarakaSyllables.markIdFor(missingPart.syllable);
  String get display => parts.map((part) => part.syllable.display).join();
  String get audioAsset => _audioAsset ?? 'tts:$display';
  String get position => missingIndex == 0
      ? 'в начале'
      : missingIndex == parts.length - 1
      ? 'в конце'
      : 'в середине';

  List<Atom> get resultAtoms => [missingPart.form, missingPart.harakaAtom];

  Map<String, bool> atomResults(ConnectionBuildEvaluation result) => {
    missingPart.form.id: result.formCorrect,
    missingPart.harakaAtom.id: result.harakaCorrect,
  };

  List<String?> preview(String? formId, String? markId) => [
    for (final (index, part) in parts.indexed)
      if (index == missingIndex)
        switch (formOptions.firstWhereOrNull((form) => form.id == formId)) {
          final form? => ConnectedLetterGlyph.forForm(form, markId),
          null => null,
        }
      else
        ConnectedLetterGlyph.forForm(
          part.form,
          HarakaSyllables.markIdFor(part.syllable),
        ),
  ];

  ConnectionBuildEvaluation evaluate({
    required String formId,
    required String markId,
  }) => ConnectionBuildEvaluation(
    formCorrect: formId == expectedFormId,
    harakaCorrect: markId == expectedMarkId,
  );
}

class ConnectionBuildPart {
  const ConnectionBuildPart({required this.form, required this.syllable});

  final Atom form;
  final Atom syllable;

  // На ба в курсе изучаются сами знаки, а не старые атомы vowel.ba.*.
  Atom get harakaAtom => syllable.letterId == 'ba'
      ? HarakaSyllables.marks.firstWhere(
          (mark) => mark.id == HarakaSyllables.markIdFor(syllable),
        )
      : syllable;
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
