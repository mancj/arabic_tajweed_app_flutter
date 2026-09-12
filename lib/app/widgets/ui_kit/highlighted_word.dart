import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

typedef HighlightedWordText = ({
  String word,
  int highlightStart,
  int highlightLength,
});

/// Растягивает только соединения вокруг рассматриваемой буквы.
///
/// Строка хранится в логическом порядке Unicode: перед буквой — соединение
/// справа на экране, после неё — соединение слева. Возвращаемый диапазон
/// включает букву и добавленные к ней татвили, но не соседние буквы.
HighlightedWordText stretchHighlightedLetter({
  required String word,
  required int index,
  required LetterForm form,
  int tatweelCount = 3,
}) {
  if (index < 0 || index >= word.length) {
    return (word: word, highlightStart: index, highlightLength: 0);
  }
  if (tatweelCount <= 0) {
    return (word: word, highlightStart: index, highlightLength: 1);
  }

  final tatweel = List.filled(tatweelCount, 'ـ').join();
  final before = switch (form) {
    LetterForm.medial || LetterForm.finalForm => tatweel,
    LetterForm.isolated || LetterForm.initial => '',
  };
  final after = switch (form) {
    LetterForm.initial || LetterForm.medial => tatweel,
    LetterForm.isolated || LetterForm.finalForm => '',
  };
  return (
    word:
        '${word.substring(0, index)}$before${word[index]}$after'
        '${word.substring(index + 1)}',
    highlightStart: index,
    highlightLength: before.length + 1 + after.length,
  );
}

/// Арабское слово с одной подсвеченной буквой.
///
/// Слово рисуется целиком одним стилем, а подсветка — тем же словом
/// поверх, обрезанным по боксу нужной буквы. Так соединение букв никогда
/// не ломается: раскраска по спанам могла бы разбить шейпинг, а тут
/// текст один и тот же в обоих слоях.
class HighlightedWord extends StatelessWidget {
  const HighlightedWord({
    required this.word,
    required this.index,
    this.form,
    this.fontSize = 64,
    this.color,
    this.highlight,
    Key? key,
  }) : super(key: key);

  final String word;
  final int index;
  final LetterForm? form;
  final double fontSize;
  final Color? color;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final display = form == null
        ? (word: word, highlightStart: index, highlightLength: 1)
        : stretchHighlightedLetter(word: word, index: index, form: form!);
    final painter = _Painter(
      word: display.word,
      highlightStart: display.highlightStart,
      highlightLength: display.highlightLength,
      fontSize: fontSize,
      color: color ?? UIColors.text,
      highlight: highlight ?? UIColors.primary,
    );
    return CustomPaint(size: painter.size, painter: painter);
  }
}

class _Painter extends CustomPainter {
  _Painter({
    required this.word,
    required this.highlightStart,
    required this.highlightLength,
    required this.fontSize,
    required this.color,
    required this.highlight,
  }) : _base = _layout(word, fontSize, color);

  final String word;
  final int highlightStart;
  final int highlightLength;
  final double fontSize;
  final Color color;
  final Color highlight;
  final TextPainter _base;

  Size get size => _base.size;

  static TextPainter _layout(String word, double fontSize, Color color) =>
      TextPainter(
        text: TextSpan(
          text: word,
          style: UITextStyles.arabicRegular(
            fontSize,
            height: 1,
          ).copyWith(color: color),
        ),
        textDirection: TextDirection.rtl,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    _base.paint(canvas, Offset.zero);
    final highlightEnd = highlightStart + highlightLength;
    if (highlightStart < 0 ||
        highlightLength <= 0 ||
        highlightEnd > word.length) {
      return;
    }

    final boxes = _base.getBoxesForSelection(
      TextSelection(baseOffset: highlightStart, extentOffset: highlightEnd),
    );
    if (boxes.isEmpty) return;

    final clip = boxes
        .map((b) => b.toRect())
        .reduce((a, b) => a.expandToInclude(b));
    canvas
      ..save()
      ..clipRect(clip);
    _layout(word, fontSize, highlight).paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Painter old) =>
      old.word != word ||
      old.highlightStart != highlightStart ||
      old.highlightLength != highlightLength ||
      old.fontSize != fontSize ||
      old.color != color ||
      old.highlight != highlight;
}
