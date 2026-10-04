import 'dart:math';

import 'package:collection/collection.dart';

import 'atom.dart';
import 'haraka_syllables.dart';

/// Звучащий слог собирается двумя независимыми выборами.
class SyllableBuildQuestion {
  SyllableBuildQuestion({
    required this.prompt,
    required List<Atom> letterOptions,
  }) : letterOptions = List.unmodifiable(letterOptions);

  final Atom prompt;

  /// Знакомые отдельные буквы или слоги; виден только глиф без огласовки.
  final List<Atom> letterOptions;

  String get expectedMarkId => HarakaSyllables.markIdFor(prompt);

  String? preview(String? letterId, String? markId) {
    final letter = letterOptions.firstWhereOrNull(
      (atom) => atom.letterId == letterId,
    );
    if (letter == null) return null;
    final glyph = HarakaSyllables.bareGlyphFor(letter);
    if (markId == null) return glyph;
    final mark = HarakaSyllables.marks.firstWhereOrNull(
      (atom) => atom.id == markId,
    );
    return mark == null ? null : HarakaSyllables.applyMark(glyph, mark);
  }

  SyllableBuildEvaluation evaluate({
    required String letterId,
    required String markId,
  }) => SyllableBuildEvaluation(
    letterCorrect: letterId == prompt.letterId,
    harakaCorrect: markId == expectedMarkId,
  );

  /// Только полные знакомые тройки: любая сборка из предложенных частей
  /// уже есть в переданном пуле, задание не вводит новые сочетания само.
  static SyllableBuildQuestion generate(List<Atom> pool, {Random? random}) {
    final rng = random ?? Random();
    final markIds = HarakaSyllables.marks.map((mark) => mark.id).toSet();
    final families = pool
        .where(
          (atom) =>
              atom.kind == AtomKind.syllable &&
              atom.letterId != null &&
              atom.audioAsset != null &&
              atom.tracing?.startsWith('harakat/') == true,
        )
        .toSet()
        .groupListsBy((atom) => atom.letterId)
        .values
        .where(
          (family) => markIds.every(
            (id) => family.any((atom) => HarakaSyllables.markIdFor(atom) == id),
          ),
        )
        .toList();
    if (families.length < 3) {
      throw ArgumentError('Нужны полные тройки слогов минимум трёх букв');
    }
    final family = families[rng.nextInt(families.length)];
    final prompts = family
        .where((atom) => markIds.contains(HarakaSyllables.markIdFor(atom)))
        .toList();
    final prompt = prompts[rng.nextInt(prompts.length)];
    final distractors =
        families
            .where((other) => other.first.letterId != prompt.letterId)
            .toList()
          ..shuffle(rng);
    final options = [prompt, ...distractors.take(2).map((other) => other.first)]
      ..shuffle(rng);
    return SyllableBuildQuestion(prompt: prompt, letterOptions: options);
  }
}

class SyllableBuildEvaluation {
  const SyllableBuildEvaluation({
    required this.letterCorrect,
    required this.harakaCorrect,
  });

  final bool letterCorrect;
  final bool harakaCorrect;
  bool get correct => letterCorrect && harakaCorrect;
}
