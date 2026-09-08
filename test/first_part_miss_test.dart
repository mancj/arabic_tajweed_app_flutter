import 'dart:io';

import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Промах стирается с холста сразу — и на первой части тоже, пока буква
/// ещё не закреплена. Там промах отличают по форме: фрагмент части из
/// нескольких линий похож на одну из её линий и остаётся, случайная черта
/// не похожа ни на что и исчезает. Под контуром остаётся и кусок линии,
/// проведённый по ней.
void main() {
  TracingShape letter(String name) => TracingShapeSvg.parse(
    File('assets/svg/alphabet/$name.svg').readAsStringSync(),
    id: name,
  );

  var reveals = 0;

  Future<
    (DrawingController, Rect, ResolvedTracingShape, List<TracingStrokeOutcome>)
  >
  pumpCanvas(WidgetTester tester, String name, TracingMode mode) async {
    final controller = DrawingController();
    final outcomes = <TracingStrokeOutcome>[];
    reveals = 0;
    final shape = letter(name);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 329,
            height: 329,
            child: DrawingCanvas(
              controller: controller,
              mode: mode,
              placeholder: shape,
              placeholderPadding: 0,
              showDemo: false,
              onStrokeOutcome: outcomes.add,
              onReveal: () => reveals++,
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(DrawingCanvas));
    return (controller, box, shape.resolve(box.size, padding: 0), outcomes);
  }

  List<Offset> along(Path path, Offset origin, {double until = 1}) {
    final metric = path.computeMetrics().first;
    return [
      for (var d = 0.0; d <= metric.length * until; d += 4)
        metric.getTangentForOffset(d)!.position + origin,
    ];
  }

  Future<void> draw(WidgetTester tester, List<Offset> points) async {
    final gesture = await tester.startGesture(points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point);
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('случайная черта на первой части стирается', (tester) async {
    final (controller, box, _, outcomes) = await pumpCanvas(
      tester,
      'ba_base',
      TracingMode.freehand,
    );
    await draw(tester, [
      box.topLeft + const Offset(40, 40),
      box.topLeft + const Offset(120, 90),
      box.topLeft + const Offset(200, 60),
    ]);
    expect(outcomes, [TracingStrokeOutcome.missed]);
    expect(controller.strokes, isEmpty);
  });

  testWidgets('первая линия части из двух остаётся, вторая собирает часть', (
    tester,
  ) async {
    final (controller, box, shape, outcomes) = await pumpCanvas(
      tester,
      'hha_mid',
      TracingMode.freehand,
    );
    final part = shape.parts.first;
    expect(part.paths.length, 2, reason: 'ـحـ рисуется двумя линиями');

    await draw(tester, along(part.paths[0], box.topLeft));
    expect(outcomes, [TracingStrokeOutcome.progressed]);
    expect(controller.strokes.length, 1);

    await draw(tester, along(part.paths[1], box.topLeft));
    expect(outcomes.last, TracingStrokeOutcome.completed);
  });

  testWidgets('под контуром кусок линии остаётся', (tester) async {
    final (controller, box, shape, outcomes) = await pumpCanvas(
      tester,
      'ba_base',
      TracingMode.tracing,
    );
    await draw(
      tester,
      along(shape.parts.first.paths.first, box.topLeft, until: .5),
    );
    expect(outcomes, [TracingStrokeOutcome.progressed]);
    expect(controller.strokes.length, 1);
  });

  testWidgets('третий промах подряд открывает подсказку, два — нет', (
    tester,
  ) async {
    final (controller, box, _, outcomes) = await pumpCanvas(
      tester,
      'ba_base',
      TracingMode.freehand,
    );
    final scribble = [
      box.topLeft + const Offset(40, 40),
      box.topLeft + const Offset(120, 90),
      box.topLeft + const Offset(200, 60),
    ];
    await draw(tester, scribble);
    await draw(tester, scribble);
    expect(reveals, 0);
    await draw(tester, scribble);
    expect(reveals, 1);
    expect(outcomes, everyElement(TracingStrokeOutcome.missed));
    expect(controller.strokes, isEmpty);
  });
}
