import 'package:flutter/material.dart';

import 'drawing_stroke.dart';

/// Рисует список штрихов толстой линией с круглыми концами и стыками.
class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final Listenable? repaint;

  DrawingPainter({required this.strokes, this.repaint})
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (stroke.isDot) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      canvas.drawPath(stroke.toPath(), paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}
