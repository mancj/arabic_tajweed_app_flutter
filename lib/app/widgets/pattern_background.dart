import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';

/// Фон страницы: пунктирная сетка с ромбами в узлах.
///
/// Рисуется на всю доступную площадь и не перехватывает жесты.
class PatternBackground extends StatelessWidget {
  /// Ширина фрейма в макете — база для масштабирования сетки.
  static const _designWidth = 440.0;

  const PatternBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PatternPainter(scale: scale),
      ),
    );
  }
}

/// Рисует бесконечно повторяющуюся ячейку паттерна.
///
/// Ячейка — квадрат [_cell] с пунктирными сторонами и ромбом в каждом узле.
/// Все размеры заданы для макетной ширины 440pt и масштабируются под экран.
class _PatternPainter extends CustomPainter {
  /// Шаг сетки.
  static const _cell = 33.0;

  /// Диагональ ромба в узле сетки.
  static const _diamond = 4.0;

  /// Шаг и радиус точек пунктира.
  static const _dotStep = 6.0;
  static const _dotRadius = .7;

  /// Скругление углов ромба.
  static const _diamondRadius = 0;

  final double scale;

  _PatternPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = _cell * scale;
    final dotStep = _dotStep * scale;
    final half = _diamond * scale / 2;

    final dotPaint = Paint()..color = UIColors.patternDot;
    final diamondPaint = Paint()..color = UIColors.patternNode;

    // Пунктир не заходит под ромб: точки ближе половины диагонали к узлу
    // пропускаются, иначе они видны сквозь полупрозрачную заливку.
    final skip = half + dotStep / 2;

    for (double x = 0; x <= size.width + cell; x += cell) {
      for (double y = dotStep / 2; y <= size.height; y += dotStep) {
        if ((y % cell) < skip || (cell - (y % cell)) < skip) continue;
        canvas.drawCircle(Offset(x, y), _dotRadius * scale, dotPaint);
      }
    }

    for (double y = 0; y <= size.height + cell; y += cell) {
      for (double x = dotStep / 2; x <= size.width; x += dotStep) {
        if ((x % cell) < skip || (cell - (x % cell)) < skip) continue;
        canvas.drawCircle(Offset(x, y), _dotRadius * scale, dotPaint);
      }
    }

    final node = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: half * math.sqrt2,
        height: half * math.sqrt2,
      ),
      Radius.circular(_diamondRadius * scale),
    );

    for (double x = 0; x <= size.width + cell; x += cell) {
      for (double y = 0; y <= size.height + cell; y += cell) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRRect(node, diamondPaint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => oldDelegate.scale != scale;
}
