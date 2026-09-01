import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';

void main() {
  const canvasSize = Size(360, 480);
  const padding = 48.0;

  Future<(DrawingController, Rect, ResolvedTracingShape, List<TracingProgress>)>
      pumpCanvas(WidgetTester tester) async {
    final controller = DrawingController(strokeWidth: 16);
    final progress = <TracingProgress>[];

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: canvasSize.width,
          height: canvasSize.height,
          child: DrawingCanvas(
            controller: controller,
            mode: TracingMode.freehand,
            placeholder: TracingShapes.arabicBa,
            placeholderPadding: padding,
            onProgress: progress.add,
          ),
        ),
      ),
    ));

    final box = tester.getRect(find.byType(DrawingCanvas));
    final shape = TracingShapes.arabicBa.resolve(box.size, padding: padding);
    return (controller, box, shape, progress);
  }

  /// Куда переедет точка фигуры, если букву нарисовали со сдвигом и мельче.
  Offset place(
    ResolvedTracingShape shape,
    Offset point, {
    Offset shift = Offset.zero,
    double scale = 1,
  }) {
    final center = shape.parts.first.paths.first.getBounds().center;
    return (point - center) * scale + center + shift;
  }

  Future<void> traceBase(
    WidgetTester tester,
    ResolvedTracingShape shape,
    Offset origin, {
    Offset shift = Offset.zero,
    double scale = 1,
  }) async {
    final metric = shape.parts.first.paths.first.computeMetrics().first;
    final points = [
      for (var d = 0.0; d < metric.length; d += 6)
        place(shape, metric.getTangentForOffset(d)!.position,
                shift: shift, scale: scale) +
            origin,
    ];

    final gesture = await tester.startGesture(points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point);
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('части засчитываются по очереди: основа, затем точка', (tester) async {
    final (controller, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft);
    expect(progress.last.completed, 1, reason: 'основа должна засчитаться сразу');
    expect(progress.last.nextLabel, 'точка');

    await tester.tapAt(shape.parts.last.dots.first + box.topLeft);
    await tester.pumpAndSettle();

    expect(progress.last.completed, 2);
    expect(progress.last.isComplete, isTrue);
    expect(controller.strokes.length, 2);
  });

  testWidgets('точка мимо не засчитывается', (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft);
    expect(progress.last.completed, 1);

    await tester.tapAt(box.topLeft + const Offset(30, 30));
    await tester.pumpAndSettle();

    expect(progress.last.completed, 1, reason: 'мимо точки — прогресс не растёт');
  });

  testWidgets('порядок частей соблюдается: точка до основы не проходит', (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);

    await tester.tapAt(shape.parts.last.dots.first + box.topLeft);
    await tester.pumpAndSettle();

    expect(progress, isEmpty, reason: 'первой ждём основу, а не точку');
  });

  testWidgets('форма засчитывается, даже если нарисована в другом месте и мельче',
      (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft,
        shift: const Offset(-70, 90), scale: 0.65);

    expect(progress.last.completed, 1);
    expect(progress.last.nextLabel, 'точка');
  });

  testWidgets('слишком мелкая каракуля не засчитывается', (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft, scale: 0.08);

    expect(progress, isEmpty);
  });

  testWidgets('точка ставится к своей букве, а не к центру холста',
      (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);
    const shift = Offset(-70, 90);
    const scale = 0.65;

    await traceBase(tester, shape, box.topLeft, shift: shift, scale: scale);
    expect(progress.last.completed, 1);

    // Каноническое место точки теперь мимо: буква стоит там, где её нарисовали.
    await tester.tapAt(shape.parts.last.dots.first + box.topLeft);
    await tester.pumpAndSettle();
    expect(progress.last.completed, 1);

    await tester.tapAt(
      place(shape, shape.parts.last.dots.first, shift: shift, scale: scale) +
          box.topLeft,
    );
    await tester.pumpAndSettle();
    expect(progress.last.isComplete, isTrue);
  });

  testWidgets('точку можно поставить неточно, но с той же стороны',
      (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft);
    final dot = shape.parts.last.dots.first;

    // Мимо на треть высоты буквы вбок и вниз — рука, а не другая буква.
    await tester.tapAt(dot + box.topLeft + const Offset(26, 18));
    await tester.pumpAndSettle();
    expect(progress.last.isComplete, isTrue);
  });

  testWidgets('точка с другой стороны основы не проходит', (tester) async {
    final (_, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft);
    final base = shape.parts.first.paths.first.getBounds();

    // Сверху вместо низа — это уже ت, а не ب.
    await tester.tapAt(Offset(base.center.dx, base.top - 30) + box.topLeft);
    await tester.pumpAndSettle();
    expect(progress.last.completed, 1);
  });

  testWidgets('основу можно нарисовать двумя штрихами', (tester) async {
    final (controller, box, shape, progress) = await pumpCanvas(tester);
    final metric = shape.parts.first.paths.first.computeMetrics().first;

    Future<void> drawSegment(double from, double to) async {
      final points = [
        for (var d = metric.length * from; d < metric.length * to; d += 6)
          metric.getTangentForOffset(d)!.position + box.topLeft,
      ];
      final gesture = await tester.startGesture(points.first);
      for (final point in points.skip(1)) {
        await gesture.moveTo(point);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await drawSegment(0, 0.5);
    expect(controller.strokes.length, 1, reason: 'первая половина — не промах');
    expect(progress, isEmpty);

    await drawSegment(0.5, 1);
    expect(progress.last.completed, 1, reason: 'вместе половины дают основу');
  });

  testWidgets('промах убирается, когда буква уже заякорена', (tester) async {
    final (controller, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft);
    expect(progress.last.completed, 1);
    expect(controller.strokes.length, 1);

    // Тапнули мимо точки: место уже определено основой, промах однозначен.
    await tester.tapAt(box.topLeft + const Offset(30, 30));
    await tester.pumpAndSettle();

    expect(controller.strokes.length, 1, reason: 'промах не остаётся на холсте');

    await tester.tapAt(shape.parts.last.dots.first + box.topLeft);
    await tester.pumpAndSettle();
    expect(progress.last.isComplete, isTrue, reason: 'промах не мешает повтору');
  });

  testWidgets('отмена откатывает собранную часть', (tester) async {
    final (controller, box, shape, progress) = await pumpCanvas(tester);

    await traceBase(tester, shape, box.topLeft);
    expect(progress.last.completed, 1);

    controller.undo();
    await tester.pumpAndSettle();

    expect(progress.last.completed, 0);
    expect(progress.last.nextLabel, 'основа');
  });
}
