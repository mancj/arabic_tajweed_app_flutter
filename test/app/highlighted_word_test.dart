import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter_test/flutter_test.dart';

/// В слове-примере растягиваются только соединения рассматриваемой буквы.
/// Точный текст защищает от растягивания всех промежутков, а диапазон — от
/// потери подсветки татвилей или окрашивания соседней буквы.
void main() {
  // Добавление всех четырёх положений в конспект не должно рисовать
  // ложное соединение слева у шести букв, которые его не допускают.
  for (final letter in ['ا', 'د', 'ذ', 'ر', 'ز', 'و']) {
    test('$letter в начале не получает черту слева', () {
      final word = '$letterب';
      expect(
        stretchHighlightedLetter(
          word: word,
          index: 0,
          form: LetterForm.initial,
        ),
        (word: word, highlightStart: 0, highlightLength: 1),
      );
    });
    test('$letter в середине растягивается только справа', () {
      expect(
        stretchHighlightedLetter(
          word: 'ب$letterب',
          index: 1,
          form: LetterForm.medial,
        ),
        (word: 'بـــ$letterب', highlightStart: 1, highlightLength: 4),
      );
    });
  }

  test('после Алиф конечная буква остаётся без соединения', () {
    expect(
      stretchHighlightedLetter(
        word: 'دار',
        index: 2,
        form: LetterForm.finalForm,
      ),
      (word: 'دار', highlightStart: 2, highlightLength: 1),
    );
  });

  test('огласовка остаётся у своей буквы при растягивании соединения', () {
    expect(
      stretchHighlightedLetter(
        word: 'مَدْرَسَة',
        index: 2,
        form: LetterForm.medial,
      ),
      (word: 'مَـــدْرَسَة', highlightStart: 2, highlightLength: 5),
    );
    expect(
      stretchHighlightedLetter(
        word: 'بَتَ',
        index: 0,
        form: LetterForm.initial,
      ),
      (word: 'بَـــتَ', highlightStart: 0, highlightLength: 5),
    );
  });

  test('начальная форма растягивается до следующей буквы', () {
    final display = stretchHighlightedLetter(
      word: 'طبخ',
      index: 0,
      form: LetterForm.initial,
    );

    expect(display, (word: 'طـــبخ', highlightStart: 0, highlightLength: 4));
  });

  test('конечная форма растягивается от предыдущей буквы', () {
    final display = stretchHighlightedLetter(
      word: 'شيخ',
      index: 2,
      form: LetterForm.finalForm,
    );

    expect(display, (word: 'شيـــخ', highlightStart: 2, highlightLength: 4));
  });

  test('средняя форма растягивается с обеих сторон', () {
    final display = stretchHighlightedLetter(
      word: 'بغداد',
      index: 1,
      form: LetterForm.medial,
    );

    expect(display, (
      word: 'بـــغـــداد',
      highlightStart: 1,
      highlightLength: 7,
    ));
  });

  test('отдельная форма не меняет слово', () {
    final display = stretchHighlightedLetter(
      word: 'ب',
      index: 0,
      form: LetterForm.isolated,
    );

    expect(display, (word: 'ب', highlightStart: 0, highlightLength: 1));
  });
}
