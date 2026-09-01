import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape.dart';

void main() {
  const matcher = TracingMatcher();
  final shape = TracingShapes.arabicBa.resolve(const Size(360, 400), padding: 48);
  final random = Random(7);

  List<Offset> traceOf(ResolvedTracingShape s, double jitter, {double portion = 1}) {
    final points = <Offset>[];
    for (final path in s.paths) {
      for (final metric in path.computeMetrics()) {
        final end = metric.length * portion;
        for (var d = 0.0; d < end; d += 4) {
          final p = metric.getTangentForOffset(d)!.position;
          points.add(p + Offset((random.nextDouble() - .5) * jitter, (random.nextDouble() - .5) * jitter));
        }
      }
    }
    return points;
  }

  DrawingStroke strokeOf(List<Offset> points) =>
      DrawingStroke(points: points, color: const Color(0xFF000000), width: 16);

  test('аккуратная обводка засчитывается', () {
    final strokes = [
      strokeOf(traceOf(shape, 6)),
      strokeOf([shape.dots.first]),
    ];
    final result = matcher.match(target: shape.whole, strokes: strokes);
    expect(result.isMatch, isTrue);
  });

  test('обводка с дрожанием в пределах линии засчитывается', () {
    final strokes = [
      strokeOf(traceOf(shape, shape.strokeWidth * 0.8)),
      strokeOf([shape.dots.first]),
    ];
    final result = matcher.match(target: shape.whole, strokes: strokes);
    expect(result.isMatch, isTrue);
  });

  test('половина буквы не засчитывается', () {
    final result = matcher.match(target: shape.whole, strokes: [strokeOf(traceOf(shape, 4, portion: 0.5))]);
    expect(result.isMatch, isFalse);
  });

  test('без точки под буквой не засчитывается', () {
    final result = matcher.match(target: shape.whole, strokes: [strokeOf(traceOf(shape, 6))]);
    expect(result.isMatch, isFalse);
  });

  test('каракули мимо не засчитываются', () {
    final points = [for (var i = 0; i < 120; i++) Offset(40.0 + i, 40.0 + (i % 20))];
    final result = matcher.match(target: shape.whole, strokes: [strokeOf(points)]);
    expect(result.isMatch, isFalse);
  });

  test('мазня поверх буквы не засчитывается', () {
    final points = [
      ...traceOf(shape, 6),
      for (var i = 0; i < 300; i++) Offset(random.nextDouble() * 360, random.nextDouble() * 400),
    ];
    final result = matcher.match(target: shape.whole, strokes: [strokeOf(points)]);
    expect(result.isMatch, isFalse);
  });
}
