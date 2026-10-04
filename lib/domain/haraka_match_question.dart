import 'dart:math';

import 'package:collection/collection.dart';

import 'atom.dart';
import 'haraka_syllables.dart';

/// Один звучащий слог и несколько написаний с той же огласовкой.
/// Пул задаётся снаружи: задание само не вводит новые сочетания.
class HarakaMatchQuestion {
  HarakaMatchQuestion({required this.prompt, required List<Atom> options})
    : options = List.unmodifiable(options);

  final Atom prompt;
  final List<Atom> options;

  Set<String> get answerIds => options
      .where(
        (atom) =>
            HarakaSyllables.markIdFor(atom) ==
            HarakaSyllables.markIdFor(prompt),
      )
      .map((atom) => atom.id)
      .toSet();

  bool isCorrect(Set<String> selected) =>
      const SetEquality<String>().equals(answerIds, selected);

  static HarakaMatchQuestion generate(List<Atom> pool, {Random? random}) {
    final rng = random ?? Random();
    final syllables = pool
        .where(
          (atom) =>
              atom.kind == AtomKind.syllable &&
              atom.audioAsset != null &&
              atom.tracing?.startsWith('harakat/') == true,
        )
        .toSet()
        .toList();
    final candidates = syllables.where((prompt) {
      final mark = HarakaSyllables.markIdFor(prompt);
      return syllables.any(
            (atom) =>
                atom.letterId != prompt.letterId &&
                HarakaSyllables.markIdFor(atom) == mark,
          ) &&
          syllables
                  .where((atom) => HarakaSyllables.markIdFor(atom) != mark)
                  .length >=
              2;
    }).toList();
    if (candidates.isEmpty) {
      throw ArgumentError('Недостаточно знакомых слогов для сравнения');
    }
    final prompt = candidates[rng.nextInt(candidates.length)];
    final mark = HarakaSyllables.markIdFor(prompt);
    final matches =
        syllables
            .where(
              (atom) =>
                  atom.letterId != prompt.letterId &&
                  HarakaSyllables.markIdFor(atom) == mark,
            )
            .toList()
          ..shuffle(rng);
    final misses =
        syllables
            .where((atom) => HarakaSyllables.markIdFor(atom) != mark)
            .toList()
          ..shuffle(rng);
    // Та же буква с другим знаком мешает выбирать по согласной.
    final trap = misses.firstWhereOrNull(
      (atom) => atom.letterId == prompt.letterId,
    );
    final count = 1 + rng.nextInt(min(3, matches.length));
    final options = [
      ...matches.take(count),
      if (trap != null) trap,
      ...misses
          .where((atom) => atom != trap)
          .take(6 - count - (trap == null ? 0 : 1)),
    ]..shuffle(rng);
    return HarakaMatchQuestion(prompt: prompt, options: options);
  }
}
