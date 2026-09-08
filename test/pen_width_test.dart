import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';

void main() {
  const canvasSize = Size(360, 480);
  const padding = 48.0;

  Future<DrawingController> pumpCanvas(
    WidgetTester tester, {
    double? strokeWidth,
    double penScale = 1,
  }) async {
    final controller = DrawingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: DrawingCanvas(
              controller: controller,
              strokeWidth: strokeWidth,
              penScale: penScale,
              placeholder: TracingShapes.arabicBa,
              placeholderPadding: padding,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('без фигуры и явной толщины — перо по умолчанию', (tester) async {
    final controller = DrawingController();
    await tester.pumpWidget(
      MaterialApp(home: DrawingCanvas(controller: controller)),
    );
    await tester.pump();

    expect(
      controller.strokeWidth,
      closeTo(DrawingCanvas.defaultStrokeWidth * 1.1, 0.01),
    );
  });

  testWidgets('без явной толщины перо берётся из фигуры', (tester) async {
    final controller = await pumpCanvas(tester);
    final shape = TracingShapes.arabicBa.resolve(canvasSize, padding: padding);

    expect(controller.strokeWidth, closeTo(shape.strokeWidth, 0.01));
  });

  testWidgets('явная толщина сильнее фигуры', (tester) async {
    final controller = await pumpCanvas(tester, strokeWidth: 12);
    expect(controller.strokeWidth, 12);
  });

  /// Перо шире линии буквы: обводят пальцем, и попадание считается от пера.
  /// Заливку это не трогает — там своя толщина, из фигуры.
  testWidgets('перо шире линии буквы во столько же раз', (tester) async {
    final controller = await pumpCanvas(tester, penScale: 1.5);
    final shape = TracingShapes.arabicBa.resolve(canvasSize, padding: padding);

    expect(controller.strokeWidth, closeTo(shape.strokeWidth * 1.5, 0.01));
  });

  testWidgets('явная толщина тоже умножается', (tester) async {
    final controller = await pumpCanvas(tester, strokeWidth: 12, penScale: 1.5);
    expect(controller.strokeWidth, closeTo(18, 0.01));
  });
}
