// Защищает автоматическое размещение огласовок: верхние знаки не должны
// пересекать точки букв, а касра должна оставаться ниже всей буквы.
import 'dart:ui';

import 'package:arabic_tajweed_app/app/widgets/drawing/haraka_shape_layout.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('верхняя огласовка располагается выше точек буквы', () {
    final letter = _shape('kha_base', const Rect.fromLTWH(80, 60, 170, 200));
    final haraka = _shape(
      'harakat/fatha',
      const Rect.fromLTWH(140, 70, 50, 20),
    );

    final placed = HarakaShapeLayout.place(haraka: haraka, letter: letter);

    expect(
      placed.bounds.bottom,
      closeTo(letter.bounds.top - HarakaShapeLayout.gap, 0.001),
    );
    expect(placed.bounds.center.dx, closeTo(letter.bounds.center.dx, 0.001));
  });

  test('касра располагается ниже всей буквы', () {
    final letter = _shape('ba_base', const Rect.fromLTWH(80, 100, 170, 130));
    final kasra = _shape(
      'harakat/kasra',
      const Rect.fromLTWH(140, 230, 50, 20),
    );

    final placed = HarakaShapeLayout.place(haraka: kasra, letter: letter);

    expect(
      placed.bounds.top,
      closeTo(letter.bounds.bottom + HarakaShapeLayout.gap, 0.001),
    );
    expect(placed.bounds.center.dx, closeTo(letter.bounds.center.dx, 0.001));
  });
}

TracingShape _shape(String id, Rect rect) => TracingShape(
  id: id,
  label: id,
  strokeWidth: 0.01,
  viewBox: const Rect.fromLTWH(0, 0, 329, 323),
  parts: [
    TracingShapePart(
      id: id,
      label: id,
      paths: [
        Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close(),
      ],
    ),
  ],
);
