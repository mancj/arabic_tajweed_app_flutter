import 'dart:math';

import 'atom.dart';
import 'connection_build_question.dart';
import 'reading_word.dart';
import 'word_build_question.dart';

/// Общая сборка примеров для курса и отладки. Пул определяет, какие
/// слоги и формы доступны; недостающий материал не создаётся скрыто.
class ConnectedWordContent {
  ConnectedWordContent(List<Atom> atoms, {required this.words, Random? random})
    : atoms = {for (final atom in atoms) atom.id: atom},
      _random = random ?? Random();

  final Map<String, Atom> atoms;
  final List<ReadingWord> words;
  final Random _random;

  List<ConnectionBuildPart>? _parts(List<String> ids) {
    final syllables = ids.map((id) => atoms['vowel.$id']).nonNulls.toList();
    if (syllables.length != ids.length) return null;
    final parts = <ConnectionBuildPart>[];
    for (final (index, syllable) in syllables.indexed) {
      final joinsBefore =
          index > 0 &&
          atoms.containsKey('${syllables[index - 1].letterId}.initial');
      final joinsAfter =
          index < syllables.length - 1 &&
          atoms.containsKey('${syllable.letterId}.initial');
      final position = switch ((joinsBefore, joinsAfter)) {
        (true, true) => LetterForm.medial,
        (false, true) => LetterForm.initial,
        (true, false) => LetterForm.finalForm,
        (false, false) => LetterForm.isolated,
      };
      final form = atoms['${syllable.letterId}.${position.name}'];
      if (form == null) return null;
      parts.add(
        ConnectionBuildPart(form: _hamzaForm(form), syllable: syllable),
      );
    }
    return parts;
  }

  Atom _hamzaForm(Atom form) =>
      form.letterId == 'alif' ? form.copyWith(display: 'أ') : form;

  List<Atom> _forms(Atom expected) {
    final options =
        atoms.values
            .where(
              (atom) => atom.letterId == expected.letterId && atom.form != null,
            )
            .where(
              (atom) =>
                  atom.form != LetterForm.isolated ||
                  expected.form == LetterForm.isolated ||
                  !atoms.containsKey('${expected.letterId}.initial'),
            )
            .map(_hamzaForm)
            .toList()
          ..shuffle(_random);
    if (options.length <= 3) return options;
    return [
      expected,
      ...options.where((atom) => atom.id != expected.id).take(2),
    ]..shuffle(_random);
  }

  WordBuildQuestion? word(ReadingWord example) {
    final assembled = _parts(example.syllableIds);
    if (assembled == null ||
        assembled.any(
          (part) => !atoms.containsKey('${part.syllable.letterId}.isolated'),
        )) {
      return null;
    }
    if (assembled.map((part) => part.syllable.display).join() !=
        example.display) {
      throw FormatException('Слоги не совпадают с написанием ${example.id}');
    }
    return WordBuildQuestion(
      contentId: example.id,
      audioAsset: example.audioAsset,
      steps: [
        for (final part in assembled)
          WordBuildStep(
            letter: atoms['${part.syllable.letterId}.isolated']!,
            part: part,
            formOptions: _forms(part.form),
          ),
      ],
    );
  }

  /// Выбор ограничен переданной подборкой и доступными слогами.
  /// Длина, блок курса и частота определяются вызывающим кодом.
  List<WordBuildQuestion> get availableWords =>
      words.map(word).nonNulls.toList();

  ConnectionBuildQuestion connection(
    WordBuildQuestion word, {
    int? missingIndex,
  }) {
    final parts = word.steps.map((step) => step.part).toList();
    final index = missingIndex ?? _random.nextInt(parts.length);
    return ConnectionBuildQuestion(
      parts: parts,
      missingIndex: index,
      formOptions: word.steps[index].formOptions,
      contentId: word.contentId,
      audioAsset: word.audioAsset,
    );
  }

  ConnectionBuildQuestion? get randomConnection {
    final words = availableWords..shuffle(_random);
    return words.isEmpty ? null : connection(words.first);
  }
}
