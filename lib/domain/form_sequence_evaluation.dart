import 'atom.dart';

/// Результат раскладки четырёх форм. Оценка не зависит от виджета и журнала.
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
  }) {
    const expected = LetterForm.values;
    final atomResults = {
      for (final option in options)
        option.id: switch (placed.indexWhere(
          (placed) => placed.id == option.id,
        )) {
          final index when index >= 0 && index < expected.length =>
            option.form == expected[index],
          _ => false,
        },
    };
    final correct =
        atomResults.length == expected.length &&
        atomResults.values.every((value) => value);
    final slotResults = [
      for (final (index, position) in expected.indexed)
        index < placed.length && placed[index].form == position,
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
