import 'package:collection/collection.dart';

import 'atom.dart';
import 'explanation_document.dart';

/// Дополняет знакомую букву до трёх слогов для практики, не расширяя
/// обязательный маршрут курса. Уже существующие атомы сохраняются.
class HarakaSyllables {
  /// Пунктирный круг показывает место буквы, не подсказывая её звук.
  static const marks = [
    Atom(
      id: 'haraka.fatha',
      kind: AtomKind.haraka,
      display: '◌َ',
      label: 'Фатха',
    ),
    Atom(
      id: 'haraka.kasra',
      kind: AtomKind.haraka,
      display: '◌ِ',
      label: 'Касра',
    ),
    Atom(
      id: 'haraka.damma',
      kind: AtomKind.haraka,
      display: '◌ُ',
      label: 'Дамма',
    ),
  ];

  static String markIdFor(Atom syllable) =>
      'haraka.${syllable.tracing!.split('/').last}';

  static String bareGlyphFor(Atom syllable) => syllable.letterId == 'alif'
      ? 'أ'
      : syllable.display.replaceAll(RegExp('[َُِ]'), '');

  static String applyMark(String letter, Atom mark) =>
      (letter == 'أ' && mark.id == 'haraka.kasra' ? 'إ' : letter) +
      mark.display.replaceAll('◌', '');

  static List<Atom> completeFamily(Atom letter, List<Atom> introduced) => [
    for (final (id, mark, label) in const [
      ('fatha', '\u064e', 'фатхой'),
      ('kasra', '\u0650', 'касрой'),
      ('damma', '\u064f', 'даммой'),
    ])
      introduced.firstWhereOrNull(
            (atom) => atom.id == 'vowel.${letter.letterId}.$id',
          ) ??
          Atom(
            id: 'vowel.${letter.letterId}.$id',
            kind: AtomKind.syllable,
            display:
                (letter.letterId == 'alif'
                    ? (id == 'kasra' ? 'إ' : 'أ')
                    : letter.display) +
                mark,
            label: '${letter.label} с $label',
            letterId: letter.letterId,
            tracing: 'harakat/$id',
            audioAsset: 'audio/harakat/${letter.letterId}_$id.mp3',
            note:
                'Послушайте слог и обратите внимание на огласовку '
                'над или под буквой.',
          ),
  ];

  static ExplanationContent? explanationFor(Atom atom) {
    if (atom.kind != AtomKind.syllable ||
        atom.audioAsset == null ||
        atom.explanationAsset != null ||
        atom.note.isEmpty) {
      return null;
    }
    return ExplanationContent(
      document: ExplanationDocument(
        title: atom.label,
        blocks: [
          ExplanationLetter(
            ExplanationGlyph(glyph: atom.display, audio: atom.audioAsset),
          ),
          ExplanationText(atom.note),
        ],
      ),
    );
  }
}
