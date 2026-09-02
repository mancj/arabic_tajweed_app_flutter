import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

void main() {
  const canvasSize = Size(360, 480);
  const padding = 32.0;

  TracingShape letter(String name) => TracingShapeSvg.parse(
    File('assets/svg/alphabet/$name.svg').readAsStringSync(),
    id: name,
  );

  Future<(DrawingController, Rect, ResolvedTracingShape, List<TracingProgress>)>
  pumpLetter(WidgetTester tester, String name) async {
    final controller = DrawingController();
    final progress = <TracingProgress>[];
    final shape = letter(name);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: DrawingCanvas(
              controller: controller,
              mode: TracingMode.freehand,
              placeholder: shape,
              placeholderPadding: padding,
              onProgress: progress.add,
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(DrawingCanvas));
    return (
      controller,
      box,
      shape.resolve(box.size, padding: padding),
      progress,
    );
  }

  Future<void> tracePart(
    WidgetTester tester,
    ResolvedTracingPart part,
    Offset origin,
  ) async {
    for (final path in part.paths) {
      final metric = path.computeMetrics().first;
      final points = [
        for (var d = 0.0; d < metric.length; d += 5)
          metric.getTangentForOffset(d)!.position + origin,
      ];

      final gesture = await tester.startGesture(points.first);
      for (final point in points.skip(1)) {
        await gesture.moveTo(point);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    for (final dot in part.dots) {
      await tester.tapAt(dot + origin);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('ба из SVG собирается целиком', (tester) async {
    final (_, box, shape, progress) = await pumpLetter(tester, 'ba_base');

    await tracePart(tester, shape.parts.first, box.topLeft);
    expect(progress.last.completed, 1);
    expect(progress.last.nextLabel, 'точка');

    await tracePart(tester, shape.parts.last, box.topLeft);
    expect(progress.last.isComplete, isTrue);
  });

  testWidgets('та требует обе точки', (tester) async {
    final (_, box, shape, progress) = await pumpLetter(tester, 'ta_base');

    await tracePart(tester, shape.parts.first, box.topLeft);
    expect(progress.last.completed, 1);

    await tester.tapAt(shape.parts.last.dots.first + box.topLeft);
    await tester.pumpAndSettle();
    expect(progress.last.completed, 1, reason: 'одной точки мало для ت');

    await tester.tapAt(shape.parts.last.dots.last + box.topLeft);
    await tester.pumpAndSettle();
    expect(progress.last.isComplete, isTrue);
  });

  testWidgets('букву можно нарисовать где угодно, точку — примерно', (
    tester,
  ) async {
    final (_, box, shape, progress) = await pumpLetter(tester, 'ba_base');
    final base = shape.parts.first.paths.first;
    final center = base.getBounds().center;

    // Рисуем мельче и в стороне, да ещё и дрожащей рукой.
    Offset place(Offset p) =>
        (p - center) * 0.7 + center + const Offset(-50, 60);

    final metric = base.computeMetrics().first;
    final random = Random(5);
    final points = [
      for (var d = 0.0; d < metric.length; d += 2)
        place(metric.getTangentForOffset(d)!.position) +
            Offset(
              (random.nextDouble() - .5) * 5,
              (random.nextDouble() - .5) * 5,
            ) +
            box.topLeft,
    ];

    final gesture = await tester.startGesture(points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(progress.last.completed, 1, reason: 'форма верная — место не важно');

    // Точка под своей буквой, с промахом в полтора пера.
    await tester.tapAt(
      place(shape.parts.last.dots.first) + const Offset(14, 10) + box.topLeft,
    );
    await tester.pumpAndSettle();

    expect(progress.last.isComplete, isTrue);
  });

  testWidgets('то собирается одной основой, зо — основой и точкой', (
    tester,
  ) async {
    final to = letter('to_base');
    expect(to.parts.length, 1);
    expect(to.parts.single.dots, isEmpty);

    final zho = letter('zho_base');
    expect(zho.parts.length, 2);
    // Точка у ظ пишется после основы, хотя в файле идёт вторым path без id:
    // порядок восстанавливается по смыслу.
    expect(zho.parts.first.paths.length, 1);
    expect(zho.parts.last.dots.length, 1);

    final (_, box, shape, progress) = await pumpLetter(tester, 'zho_base');
    await tracePart(tester, shape.parts.first, box.topLeft);
    expect(progress.last.completed, 1);
    expect(progress.last.nextLabel, 'точка');

    await tracePart(tester, shape.parts.last, box.topLeft);
    expect(progress.last.isComplete, isTrue);
  });

  testWidgets('то и зо делят одну основу', (tester) async {
    final (_, box, to, _) = await pumpLetter(tester, 'to_base');
    final zho = letter('zho_base').resolve(box.size, padding: padding);

    expect(
      zho.parts.first.paths.first.getBounds(),
      to.parts.first.paths.first.getBounds(),
      reason: 'общий viewBox держит основы на одном месте',
    );
  });

  testWidgets('то готово, как только обведена основа', (tester) async {
    final (_, box, shape, progress) = await pumpLetter(tester, 'to_base');

    await tracePart(tester, shape.parts.first, box.topLeft);
    expect(progress.last.isComplete, isTrue, reason: 'у ط всего одна часть');
  });

  testWidgets('точку ба нельзя поставить сверху, как у та', (tester) async {
    final (_, box, shape, progress) = await pumpLetter(tester, 'ba_base');
    final taDots = letter(
      'ta_base',
    ).resolve(box.size, padding: padding).parts.last.dots;

    await tracePart(tester, shape.parts.first, box.topLeft);
    await tester.tapAt(taDots.first + box.topLeft);
    await tester.pumpAndSettle();

    expect(progress.last.completed, 1, reason: 'ب с точкой сверху — это не ب');
  });
}
