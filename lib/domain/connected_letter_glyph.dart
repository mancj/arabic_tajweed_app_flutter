import 'package:collection/collection.dart';

import 'atom.dart';
import 'haraka_syllables.dart';

/// Сохраняет выбранную форму: автоматическое соединение текста не должно
/// исправлять ответ ученика. Между полученными частями ставится ZWNJ.
class ConnectedLetterGlyph {
  static String forForm(Atom form, String? markId) {
    final joinsBefore = switch (form.form) {
      LetterForm.medial || LetterForm.finalForm => true,
      _ => false,
    };
    final joinsAfter = switch (form.form) {
      LetterForm.initial || LetterForm.medial => true,
      _ => false,
    };
    final bare = form.display.replaceAll('ـ', '');
    final mark = HarakaSyllables.marks.firstWhereOrNull(
      (mark) => mark.id == markId,
    );
    return '${joinsBefore ? '\u200d' : ''}'
        '${mark == null ? bare : HarakaSyllables.applyMark(bare, mark)}'
        '${joinsAfter ? '\u200d' : ''}';
  }
}
