import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';

void main() {
  const canvasSize = Size(360, 480);
  const padding = 48.0;

  Future<DrawingController> pumpCanvas(
    WidgetTester tester, {
    double? strokeWidth,
  }) async {
    final controller = DrawingController(strokeWidth: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: DrawingCanvas(
              controller: controller,
              strokeWidth: strokeWidth,
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

  testWidgets('без явной толщины перо берётся из фигуры', (tester) async {
    final controller = await pumpCanvas(tester);
    final shape = TracingShapes.arabicBa.resolve(canvasSize, padding: padding);

    expect(controller.strokeWidth, closeTo(shape.strokeWidth, 0.01));
  });

  testWidgets('явная толщина сильнее фигуры', (tester) async {
    final controller = await pumpCanvas(tester, strokeWidth: 12);
    expect(controller.strokeWidth, 12);
  });
}
