import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';

final harakaTestSyllables = [
  for (final (id, glyph) in const [
    ('ba', 'ب'),
    ('mim', 'م'),
    ('ra', 'ر'),
    ('kaf', 'ك'),
  ])
    ...HarakaSyllables.completeFamily(
      Atom(
        id: '$id.isolated',
        letterId: id,
        kind: AtomKind.letterForm,
        display: glyph,
      ),
      const [],
    ),
];

Atom harakaTestAtom(String letter, String mark) =>
    harakaTestSyllables.firstWhere((atom) => atom.id == 'vowel.$letter.$mark');
