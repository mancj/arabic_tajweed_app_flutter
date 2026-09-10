import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';

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
    this.fontSize = 64,
    this.color,
    this.highlight,
    Key? key,
  }) : super(key: key);

  final String word;
  final int index;
  final double fontSize;
  final Color? color;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final painter = _Painter(
      word: word,
      index: index,
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
    required this.index,
    required this.fontSize,
    required this.color,
    required this.highlight,
  }) : _base = _layout(word, fontSize, color);

  final String word;
  final int index;
  final double fontSize;
  final Color color;
  final Color highlight;
  final TextPainter _base;

  Size get size => _base.size;

  static TextPainter _layout(String word, double fontSize, Color color) =>
      TextPainter(
        text: TextSpan(
          text: word,
          style: TextStyle(
            fontFamily: UITextStyles.fontScheherazadeNew,
            fontSize: fontSize,
            color: color,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    _base.paint(canvas, Offset.zero);
    if (index < 0 || index >= word.length) return;

    final boxes = _base.getBoxesForSelection(
      TextSelection(baseOffset: index, extentOffset: index + 1),
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
      old.index != index ||
      old.fontSize != fontSize ||
      old.color != color ||
      old.highlight != highlight;
}
