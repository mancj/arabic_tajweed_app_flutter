import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/stroke_signature.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

void main() {
  const canvasSize = Size(360, 480);
  const padding = 32.0;

  TracingShape letter(String name) => TracingShapeSvg.parse(
    File('assets/svg/alphabet/$name.svg').readAsStringSync(),
    id: name,
  );

  test('шин разбирается на основу и три точки, син — на одну основу', () {
    final shin = letter('shin_base');
    expect(shin.parts.length, 2);
    expect(shin.parts.first.paths.length, 1);
    expect(shin.parts.last.dots.length, 3);
    // Точки над основой: у ش они сверху.
    final base = shin.parts.first.paths.first.getBounds();
    expect(shin.parts.last.dots.every((d) => d.dy < base.top), isTrue);

    final sin = letter('sin_base');
    expect(sin.parts.length, 1);
    expect(sin.parts.first.dots, isEmpty);
  });

  test('син и шин делят одну основу', () {
    final sin = letter('sin_base').resolve(canvasSize, padding: padding);
    final shin = letter('shin_base').resolve(canvasSize, padding: padding);

    // Не строгое равенство: в файлах одна контрольная точка записана как
    // 5.5 и 5.50001 — экспортировали по отдельности, а не копией.
    final a = sin.parts.first.paths.first.getBounds();
    final b = shin.parts.first.paths.first.getBounds();
    expect(a.left, closeTo(b.left, 0.01));
    expect(a.top, closeTo(b.top, 0.01));
    expect(a.width, closeTo(b.width, 0.01));
    expect(a.height, closeTo(b.height, 0.01));
    expect(
      StrokeSignature.ofPaths(
        sin.parts.first.paths,
      )!.distanceTo(StrokeSignature.ofPaths(shin.parts.first.paths)!),
      lessThan(0.001),
    );
  });

  test('основа син не путается с чашей ба', () {
    final sin = StrokeSignature.ofPaths(
      letter(
        'sin_base',
      ).resolve(canvasSize, padding: padding).parts.first.paths,
    )!;
    final ba = StrokeSignature.ofPaths(
      letter('ba_base').resolve(canvasSize, padding: padding).parts.first.paths,
      uniform: sin.uniform,
    )!;

    expect(sin.distanceTo(ba), greaterThan(0.2));
  });

  test('части буквы могут быть другой развесовки', () {
    const matcher = TracingMatcher();
    final resolved = letter('sin_base').resolve(canvasSize, padding: padding);
    final target = resolved.parts.first;
    final metric = target.paths.first.computeMetrics().first;

    final points = [
      for (var d = 0.0; d < metric.length; d += 2)
        metric.getTangentForOffset(d)!.position,
    ];
    final joint = points[(points.length * .55).round()];

    /// Хвост уходит глубже, зубцы прежние: так пишут от руки, и жёсткое
    /// соответствие «доля длины к доле длины» такую букву отвергало.
    List<Offset> deeperTail(double k) => [
      for (var i = 0; i < points.length; i++)
        i < (points.length * .55).round()
            ? points[i]
            : Offset(points[i].dx, joint.dy + (points[i].dy - joint.dy) * k),
    ];

    /// Зубцы выше при том же хвосте.
    List<Offset> tallerTeeth(double k) => [
      for (var i = 0; i < points.length; i++)
        i < (points.length * .55).round()
            ? Offset(points[i].dx, joint.dy + (points[i].dy - joint.dy) * k)
            : points[i],
    ];

    bool accepts(List<Offset> pts) => matcher
        .match(
          target: target,
          strokes: [
            DrawingStroke(
              points: pts,
              color: const Color(0xFF000000),
              width: 20,
            ),
          ],
          penWidth: 20,
          structural: true,
        )
        .isMatch;

    expect(accepts(deeperTail(1.6)), isTrue, reason: 'хвост глубже');
    expect(accepts(tallerTeeth(1.5)), isTrue, reason: 'зубцы выше');
    expect(
      accepts(points.sublist(0, (points.length * .62).round())),
      isFalse,
      reason: 'два зубца вместо трёх',
    );
    expect(
      accepts([...points.sublist(0, (points.length * .2).round()), ...points]),
      isFalse,
      reason: 'четыре зубца вместо трёх',
    );
  });

  testWidgets('шин собирается по памяти: основа и три точки', (tester) async {
    final controller = DrawingController();
    final progress = <TracingProgress>[];
    final shape = letter('shin_base');

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
    final resolved = shape.resolve(box.size, padding: padding);

    // Основу рисуют одним росчерком: три зубца и хвост, не отрывая пальца.
    final metric = resolved.parts.first.paths.first.computeMetrics().first;
    final points = [
      for (var d = 0.0; d < metric.length; d += 2)
        metric.getTangentForOffset(d)!.position + box.topLeft,
    ];

    final gesture = await tester.startGesture(points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(progress.last.completed, 1, reason: 'основа');
    expect(progress.last.nextLabel, 'точка');

    final dots = resolved.parts.last.dots;
    for (var i = 0; i < dots.length; i++) {
      await tester.tapAt(dots[i] + box.topLeft);
      await tester.pumpAndSettle();
      expect(
        progress.last.isComplete,
        i == dots.length - 1,
        reason: 'после ${i + 1} точек из ${dots.length}',
      );
    }
  });

  testWidgets('две точки вместо трёх не завершают шин', (tester) async {
    final controller = DrawingController();
    final progress = <TracingProgress>[];
    final shape = letter('shin_base');

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
    final resolved = shape.resolve(box.size, padding: padding);
    final metric = resolved.parts.first.paths.first.computeMetrics().first;

    final gesture = await tester.startGesture(
      metric.getTangentForOffset(0)!.position + box.topLeft,
    );
    for (var d = 2.0; d < metric.length; d += 2) {
      await gesture.moveTo(
        metric.getTangentForOffset(d)!.position + box.topLeft,
      );
    }
    await gesture.up();
    await tester.pumpAndSettle();

    for (final dot in resolved.parts.last.dots.take(2)) {
      await tester.tapAt(dot + box.topLeft);
      await tester.pumpAndSettle();
    }

    expect(
      progress.last.completed,
      1,
      reason: 'без третьей точки это ﺱ, а не ﺵ',
    );
  });
}
