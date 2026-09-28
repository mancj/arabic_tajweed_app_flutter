import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';

void main() {
  testWidgets('check() видит фигуру и штрихи', (tester) async {
    final controller = DrawingController();
    const canvasSize = Size(360, 480);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: DrawingCanvas(
              controller: controller,
              placeholder: TracingShapes.arabicBa,
              placeholderPadding: 48,
            ),
          ),
        ),
      ),
    );

    final topLeft = tester.getTopLeft(find.byType(DrawingCanvas));
    final shape = TracingShapes.arabicBa.resolve(canvasSize, padding: 48);

    // Обводим линию буквы.
    final path = shape.paths.first;
    final metric = path.computeMetrics().first;
    final points = [
      for (var d = 0.0; d < metric.length; d += 6)
        metric.getTangentForOffset(d)!.position + topLeft,
    ];

    var gesture = await tester.startGesture(points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point);
    }
    await gesture.up();
    await tester.pump();

    // Ставим точку.
    await tester.tapAt(shape.dots.first + topLeft);
    await tester.pump();

    final result = controller.check();

    expect(controller.strokes.length, 2);
    expect(result.coverage, greaterThan(0.8));
    expect(result.isMatch, isTrue);

    // Перерисовка холста не должна «отцеплять» проверку от контроллера.
    await tester.pump();
    expect(controller.check().isMatch, isTrue);
  });

  /// Точка по памяти должна совпадать с касанием: возвращение сдвига
  /// помешает ставить точки буквы в выбранном пользователем месте.
  testWidgets('по памяти точка рисуется в месте касания', (tester) async {
    final controller = DrawingController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: DrawingCanvas(
            controller: controller,
            mode: TracingMode.freehand,
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(DrawingCanvas));
    await tester.tapAt(origin + const Offset(100, 100));

    expect(controller.strokes.single.points.single, const Offset(100, 100));
  });

  /// При обводке видимый контур служит точной целью, поэтому линия должна
  /// начинаться непосредственно под пальцем.
  testWidgets('при обводке линия остаётся под пальцем', (tester) async {
    final controller = DrawingController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: DrawingCanvas(controller: controller),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(DrawingCanvas));
    await tester.tapAt(origin + const Offset(100, 100));

    expect(controller.strokes.single.points.single, const Offset(100, 100));
  });

  testWidgets('пустой холст отвечает noInput, а не нулевым результатом', (
    tester,
  ) async {
    final controller = DrawingController();

    await tester.pumpWidget(
      MaterialApp(
        home: DrawingCanvas(
          controller: controller,
          placeholder: TracingShapes.arabicBa,
        ),
      ),
    );

    final result = controller.check();
    expect(result.status, TracingMatchStatus.noInput);
    expect(result.isChecked, isFalse);
  });

  testWidgets('без холста check() отвечает noShape', (tester) async {
    final controller = DrawingController();
    expect(controller.check().status, TracingMatchStatus.noShape);
  });
}
