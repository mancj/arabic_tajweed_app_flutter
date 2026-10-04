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
    List<String>? resultAtomIds,
  }) {
    final expected = expectedAtomIds;
    final positions = LetterForm.values
        .where((form) => options.any((option) => option.form == form))
        .toList();
    final slotCount = expected?.length ?? positions.length;
    final slotResults = [
      for (var index = 0; index < slotCount; index++)
        index < placed.length &&
            options.any((option) => option.id == placed[index].id) &&
            (expected == null
                ? placed[index].form == positions[index]
                : placed[index].id == expected[index]),
    ];
    final atomResults = {
      if (resultAtomIds != null)
        for (final (index, id) in resultAtomIds.indexed) id: slotResults[index]
      else
        for (final option in options)
          option.id: switch (placed.indexWhere(
            (placed) => placed.id == option.id,
          )) {
            final index when index >= 0 && index < slotCount =>
              expected == null
                  ? option.form == positions[index]
                  : option.id == expected[index],
            _ => false,
          },
    };
    final correct =
        slotCount > 0 &&
        placed.length == slotCount &&
        atomResults.length == slotCount &&
        slotResults.every((value) => value) &&
        atomResults.values.every((value) => value);
    return FormSequenceEvaluation(
      atomResults: Map.unmodifiable(atomResults),
      slotResults: List.unmodifiable(slotResults),
      initialPlaced: correct
          ? const []
          : List.unmodifiable([
              for (var index = 0; index < slotCount; index++)
                slotResults[index] ? placed[index] : null,
            ]),
      correct: correct,
    );
  }
}
