import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String name) =>
      File('assets/svg/alphabet/$name.svg').readAsStringSync();

  test('ба разбирается на основу и точку', () {
    final shape = TracingShapeSvg.parse(read('ba_base'), id: 'ba', label: 'ب');

    expect(shape.viewBox, const Rect.fromLTWH(0, 0, 329, 329));
    expect(shape.strokeWidth, 20);
    expect(shape.parts.length, 2);

    final base = shape.parts.first;
    expect(base.paths.length, 1, reason: 'основа рисуется первой');
    expect(base.dots, isEmpty);

    final dots = shape.parts.last;
    expect(dots.paths, isEmpty);
    expect(dots.dots.length, 1);
    expect(dots.dots.first.dy, greaterThan(200), reason: 'точка ба — снизу');
  });

  test('та разбирается на основу и две точки сверху', () {
    final shape = TracingShapeSvg.parse(read('ta_base'), id: 'ta', label: 'ت');

    expect(shape.parts.length, 2);
    expect(shape.parts.first.paths.length, 1);

    final dots = shape.parts.last.dots;
    expect(dots.length, 2, reason: 'обе точки — одна часть, ставят их подряд');
    expect(dots.every((dot) => dot.dy < 100), isTrue, reason: 'точки та — сверху');
  });

  test('обе буквы стоят в одном кадре и делят одну основу', () {
    final ba = TracingShapeSvg.parse(read('ba_base'), id: 'ba');
    final ta = TracingShapeSvg.parse(read('ta_base'), id: 'ta');

    expect(ba.viewBox, ta.viewBox);

    final canvas = const Size(360, 260);
    final resolvedBa = ba.resolve(canvas, padding: 24);
    final resolvedTa = ta.resolve(canvas, padding: 24);

    expect(resolvedBa.scale, closeTo(resolvedTa.scale, 0.0001),
        reason: 'одинаковый масштаб');
    expect(resolvedBa.offset, resolvedTa.offset, reason: 'одинаковое место');

    // Чаша должна лечь ровно там же — иначе при смене буквы она прыгает.
    final bowlBa = resolvedBa.parts.first.paths.first.getBounds();
    final bowlTa = resolvedTa.parts.first.paths.first.getBounds();
    expect(bowlBa, bowlTa);
  });

  test('линия письма идёт справа налево', () {
    final shape = TracingShapeSvg.parse(read('ba_base'), id: 'ba');
    final metric = shape.parts.first.paths.first.computeMetrics().first;

    final start = metric.getTangentForOffset(0)!.position;
    final end = metric.getTangentForOffset(metric.length)!.position;
    expect(start.dx, greaterThan(end.dx));
  });

  test('габариты считаются по кривой, а не по контрольным точкам', () {
    final shape = TracingShapeSvg.parse(read('ba_base'), id: 'ba');
    final controlBounds = shape.parts.first.paths.first.getBounds();

    // Контрольная точка безье уезжает левее самой кривой: 35.4 против 70.
    expect(shape.bounds.left, greaterThan(controlBounds.left + 20));
    expect(shape.bounds.inflate(-shape.strokeWidth / 2).left, closeTo(70, 1));
  });
}
