import 'atom.dart';

/// Результат раскладки форм или звуковых слотов.
/// Оценка не зависит от виджета и журнала.
class FormSequenceEvaluation {
  const FormSequenceEvaluation({
    required this.atomResults,
    required this.slotResults,
    required this.initialPlaced,
    required this.correct,
  });

  final Map<String, bool> atomResults;
  final List<bool> slotResults;
  final List<Atom?> initialPlaced;
  final bool correct;

  static FormSequenceEvaluation evaluate({
    required List<Atom> options,
    required List<Atom> placed,
    List<String>? expectedAtomIds,
  }) {
    final expected = expectedAtomIds;
    final slotCount = expected?.length ?? LetterForm.values.length;
    final atomResults = {
      for (final option in options)
        option.id: switch (placed.indexWhere(
          (placed) => placed.id == option.id,
        )) {
          final index when index >= 0 && index < slotCount =>
            expected == null
                ? option.form == LetterForm.values[index]
                : option.id == expected[index],
          _ => false,
        },
    };
    final correct =
        atomResults.length == slotCount &&
        atomResults.values.every((value) => value);
    final slotResults = [
      for (var index = 0; index < slotCount; index++)
        index < placed.length &&
            (expected == null
                ? placed[index].form == LetterForm.values[index]
                : placed[index].id == expected[index]),
    ];
    return FormSequenceEvaluation(
      atomResults: Map.unmodifiable(atomResults),
      slotResults: List.unmodifiable(slotResults),
      initialPlaced: correct
          ? const []
          : List.unmodifiable([
              for (final (index, atom) in placed.indexed)
                slotResults[index] ? atom : null,
            ]),
      correct: correct,
    );
  }
}
