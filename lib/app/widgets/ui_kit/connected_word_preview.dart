import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Общая строка соединения: ZWJ фиксирует формы, отдельные подписи
/// не дают тексту исправить ошибку. Пропуск стоит на линии соединения.
class ConnectedWordPreview extends StatelessWidget {
  const ConnectedWordPreview({
    required this.glyphs,
    required this.activeIndex,
    required this.accent,
    required this.gapLabel,
    required this.textKey,
    this.gapKey = const ValueKey('connection-build-gap'),
    this.gapKeyFor,
    this.colors,
    this.animatedIndex,
    super.key,
  });

  final List<String?> glyphs;
  final int activeIndex;
  final Color accent;
  final String gapLabel;
  final Key textKey;
  final Key gapKey;
  final Key Function(int)? gapKeyFor;
  final List<Color?>? colors;
  final int? animatedIndex;

  @override
  Widget build(BuildContext context) {
    final written = glyphs.any((glyph) => glyph != null)
        ? glyphs.map((glyph) => glyph ?? '…').join().replaceAll('\u200d', '')
        : '';
    return Semantics(
      label: [
        if (written.isNotEmpty) written,
        if (glyphs.contains(null)) gapLabel,
      ].join('. '),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // Порядок пустых мест задан раскладкой, а не направлением
        // нейтральных символов внутри арабского текста.
        child: Row(
          key: textKey,
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final (index, glyph) in glyphs.indexed)
              if (glyph == null)
                Baseline(
                  baseline: 48,
                  baselineType: TextBaseline.alphabetic,
                  child: _ConnectionGap(
                    gapKey: gapKeyFor?.call(index) ?? gapKey,
                    color: index == activeIndex ? accent : UIColors.secondary2,
                  ),
                )
              else
                _letter(context, index, glyph),
          ],
        ),
      ),
    );
  }

  Widget _letter(BuildContext context, int index, String glyph) {
    final text = Text(
      glyph,
      key: ValueKey('connected-word-glyph-$index'),
      textDirection: TextDirection.rtl,
      style: UITextStyles.arabicRegular64Compact.copyWith(
        color:
            colors?[index] ?? (index == activeIndex ? accent : UIColors.text),
      ),
    );
    if (index != animatedIndex || MediaQuery.disableAnimationsOf(context)) {
      return text;
    }
    return KeyedSubtree(
      key: ValueKey('$index-$glyph'),
      child: text
          .animate()
          .fadeIn(duration: 180.ms)
          .slideX(
            begin: -.12,
            end: 0,
            duration: 220.ms,
            curve: Curves.easeOutCubic,
          )
          .scaleXY(
            begin: .94,
            end: 1,
            duration: 220.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class _ConnectionGap extends StatelessWidget {
  const _ConnectionGap({required this.gapKey, required this.color});

  final Key gapKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Пропуск сохраняет линию букв, ванночка стоит чуть ниже неё.
    // Значок вопроса не задаёт свою текстовую линию для всей строки.
    return IgnoreBaseline(
      child: SizedBox(
        key: gapKey,
        width: 60,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Icon(Icons.question_mark_rounded, color: color, size: 24),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -4,
              height: 8,
              child: CustomPaint(painter: _ConnectionGapPainter(color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionGapPainter extends CustomPainter {
  const _ConnectionGapPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bottom = size.height;
    final left = (size.width - 48) / 2;
    final right = size.width - left;
    final bath = Path()
      ..moveTo(left, 0)
      ..quadraticBezierTo(left, bottom, left + 8, bottom)
      ..lineTo(right - 8, bottom)
      ..quadraticBezierTo(right, bottom, right, 0);
    canvas.drawPath(bath, paint);
  }

  @override
  bool shouldRepaint(_ConnectionGapPainter oldDelegate) =>
      color != oldDelegate.color;
}
