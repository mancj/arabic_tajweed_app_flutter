import 'package:collection/collection.dart';

import 'atom.dart';
import 'connected_letter_glyph.dart';
import 'connection_build_question.dart';
import 'haraka_syllables.dart';

enum WordBuildPhase { forms, marks }

/// Последовательность букв известна приложению, ученик собирает только
/// формы, затем огласовки. Количество мест известно с начала задания.
class WordBuildQuestion {
  WordBuildQuestion({
    required List<WordBuildStep> steps,
    this.contentId,
    String? audioAsset,
  }) : assert(steps.isNotEmpty),
       steps = List.unmodifiable(steps),
       _audioAsset = audioAsset;

  final List<WordBuildStep> steps;
  final String? contentId;
  final String? _audioAsset;

  String get display => steps.map((step) => step.part.syllable.display).join();
  String get audioAsset => _audioAsset ?? 'tts:$display';

  List<Atom> get resultAtoms => {
    for (final step in steps) ...[step.part.form, step.part.harakaAtom],
  }.toList();

  Map<String, bool> atomResults(WordBuildEvaluation result) {
    final results = <String, bool>{};
    for (final (index, step) in steps.indexed) {
      final letter = result.letters[index];
      for (final (atom, correct) in [
        (step.part.form, letter.formCorrect),
        (step.part.harakaAtom, letter.harakaCorrect),
      ]) {
        results.update(
          atom.id,
          (previous) => previous && correct,
          ifAbsent: () => correct,
        );
      }
    }
    return results;
  }

  List<String?> preview(List<String?> formIds, List<String?> markIds) => [
    for (final (index, step) in steps.indexed)
      step.preview(formIds[index], markIds[index]),
  ];

  WordBuildEvaluation evaluate(List<String> formIds, List<String> markIds) =>
      WordBuildEvaluation([
        for (final (index, step) in steps.indexed)
          step.evaluate(formIds[index], markIds[index]),
      ]);
}

class WordBuildEvaluation {
  WordBuildEvaluation(List<ConnectionBuildEvaluation> letters)
    : letters = List.unmodifiable(letters);

  final List<ConnectionBuildEvaluation> letters;
  bool get correct => letters.every((letter) => letter.correct);
  int get formMistakes => letters.where((letter) => !letter.formCorrect).length;
  int get markMistakes =>
      letters.where((letter) => !letter.harakaCorrect).length;
}

class WordBuildStep {
  WordBuildStep({
    required this.letter,
    required this.part,
    required List<Atom> formOptions,
  }) : formOptions = List.unmodifiable(formOptions);

  final Atom letter;
  final ConnectionBuildPart part;
  final List<Atom> formOptions;

  String get expectedFormId => part.form.id;
  String get expectedMarkId => HarakaSyllables.markIdFor(part.syllable);

  String? preview(String? formId, String? markId) {
    final form = formOptions.firstWhereOrNull((form) => form.id == formId);
    return form == null ? null : ConnectedLetterGlyph.forForm(form, markId);
  }

  ConnectionBuildEvaluation evaluate(String formId, String markId) =>
      ConnectionBuildEvaluation(
        formCorrect: formId == expectedFormId,
        harakaCorrect: markId == expectedMarkId,
      );
}
