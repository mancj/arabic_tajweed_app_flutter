import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

void main() {
  const canvasSize = Size(360, 480);
  const padding = 32.0;
  const matcher = TracingMatcher();

  ResolvedTracingPart sinBase() => TracingShapeSvg.parse(
        File('assets/svg/alphabet/sin_base.svg').readAsStringSync(),
        id: 'sin_base',
      ).resolve(canvasSize, padding: padding).parts.first;

  /// Рука, ведущая по букве: точки вдоль линии с дрожью поперёк неё и общим
  /// сдвигом — так обводят на самом деле, и именно так соседние ветки зубца
  /// оказываются к точке ближе, чем её собственное место на линии.
  DrawingStroke handOf(ResolvedTracingPart part) {
    final jitter = part.strokeWidth * 0.8;
    const shift = Offset(0, 10);

    final points = <Offset>[];
    for (final metric in part.paths.first.computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += 6) {
        final tangent = metric.getTangentForOffset(math.min(d, metric.length));
        if (tangent == null) continue;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        points.add(
          tangent.position + normal * math.sin(d / 11) * jitter + shift,
        );
      }
    }
    return DrawingStroke(
      points: points,
      color: const Color(0xFF000000),
      width: part.strokeWidth,
    );
  }

  /// Перемычка через зубец: насколько далеко от линии буквы уходит середина
  /// отрезка между соседними точками проекции. У проекции, идущей вдоль
  /// линии, это лишь стрелка прогиба между соседними опорными точками.
  double worstChordOf(List<Offset> points, List<Offset> samples) {
    var worst = 0.0;
    for (var i = 1; i < points.length; i++) {
      final middle = (points[i - 1] + points[i]) / 2;
      var best = double.infinity;
      for (final sample in samples) {
        best = math.min(best, (middle - sample).distance);
      }
      if (best > worst) worst = best;
    }
    return worst;
  }

  test('проекция штриха на س не даёт перемычек через зубцы', () {
    final part = sinBase();
    final samples = matcher.sample(part);
    final hand = handOf(part);

    final projected = matcher.project(target: part, strokes: [hand]).single;

    expect(projected.points.length, hand.points.length);
    expect(
      worstChordOf(projected.points, samples),
      lessThan(part.strokeWidth * 0.25),
      reason: 'проекция перескочила через вершину зубца на соседнюю ветку',
    );
  });

  test('поточечная проекция в ближайшую опорную такую перемычку даёт', () {
    // Страховка для теста выше: без неё он прошёл бы и на сломанной проекции.
    final part = sinBase();
    final samples = matcher.sample(part);
    final hand = handOf(part);

    final naive = [
      for (final point in hand.points)
        samples.reduce((a, b) =>
            (point - a).distanceSquared <= (point - b).distanceSquared ? a : b),
    ];

    expect(
      worstChordOf(naive, samples),
      greaterThan(part.strokeWidth * 0.25),
    );
  });
}
