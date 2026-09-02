import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape.dart';

void main() {
  const matcher = TracingMatcher();
  final shape = TracingShapes.arabicBa.resolve(
    const Size(360, 480),
    padding: 48,
  );
  final base = shape.parts.first;
  final metric = base.paths.first.computeMetrics().first;
  final random = Random(3);

  DrawingStroke strokeOf(List<Offset> points) =>
      DrawingStroke(points: points, color: const Color(0xFF000000), width: 16);

  List<Offset> trace(double jitter) => [
    for (var d = 0.0; d < metric.length; d += 4)
      metric.getTangentForOffset(d)!.position +
          Offset(
            (random.nextDouble() - .5) * jitter,
            (random.nextDouble() - .5) * jitter,
          ),
  ];

  /// Чаша с пиком вверх посередине — та самая «W» вместо «ба».
  /// [amount] — высота пика в долях высоты буквы.
  List<Offset> spiked(double amount) {
    final height = base.paths.first.getBounds().height;
    return [
      for (var d = 0.0; d < metric.length; d += 4)
        () {
          final t = d / metric.length;
          final point = metric.getTangentForOffset(d)!.position;
          final bump = exp(-pow((t - 0.5) / 0.13, 2)) * height * amount;
          return Offset(point.dx, point.dy - bump);
        }(),
    ];
  }

  TracingMatchResult match(List<Offset> points) =>
      matcher.match(target: base, strokes: [strokeOf(points)]);

  test('«W» вместо чаши не проходит, хотя обходит всю фигуру', () {
    for (final amount in [0.35, 0.45, 0.6, 0.85]) {
      final result = match(spiked(amount));
      expect(result.isMatch, isFalse, reason: 'пик $amount: $result');
      expect(result.deviation, greaterThan(matcher.maxDeviation));
    }
  });

  test('аккуратная и дрожащая обводка проходят', () {
    for (final jitter in [8.0, base.strokeWidth * 0.7]) {
      final result = match(trace(jitter));
      expect(result.isMatch, isTrue, reason: 'дрожание $jitter: $result');
      expect(result.deviation, lessThan(matcher.maxDeviation));
    }
  });

  test('покрытие и точность сами по себе «W» не ловят', () {
    // Ради этого и добавлено отклонение: две первые метрики здесь проходят.
    final result = match(spiked(0.35));
    expect(result.coverage, greaterThan(matcher.minCoverage));
    expect(result.accuracy, greaterThan(matcher.minAccuracy));
    expect(result.isMatch, isFalse);
  });
}
