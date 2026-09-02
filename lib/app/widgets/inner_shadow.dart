import 'package:flutter/widgets.dart';

/// Внутренняя (inset) тень: `BoxShadow` в `BoxDecoration` умеет только внешние.
class InnerShadow {
  final Color color;
  final Offset offset;

  /// Радиус размытия в терминах CSS `box-shadow` — как в макете.
  final double blur;

  const InnerShadow({
    required this.color,
    this.offset = Offset.zero,
    this.blur = 0,
  });
}

/// Накладывает inset-тени поверх [child], обрезая их по [borderRadius].
class InnerShadows extends StatelessWidget {
  final BorderRadius borderRadius;
  final List<InnerShadow> shadows;
  final Widget child;

  const InnerShadows({
    required this.borderRadius,
    required this.shadows,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _InnerShadowPainter(borderRadius, shadows),
      child: child,
    );
  }
}

class _InnerShadowPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final List<InnerShadow> shadows;

  const _InnerShadowPainter(this.borderRadius, this.shadows);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(rrect);
    for (final shadow in shadows) {
      // Тень — это «дырка» формы кнопки в большом прямоугольнике: размытый
      // край дырки и есть внутренняя тень.
      final margin = shadow.blur * 3 + shadow.offset.distance + 1;
      final hole = Path.combine(
        PathOperation.difference,
        Path()..addRect(rrect.outerRect.inflate(margin)),
        Path()..addRRect(rrect),
      );
      final paint = Paint()..color = shadow.color;
      if (shadow.blur > 0) {
        // CSS-радиус размытия вдвое больше сигмы гауссианы.
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blur / 2);
      }
      canvas.drawPath(hole.shift(shadow.offset), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      old.borderRadius != borderRadius || old.shadows != shadows;
}
