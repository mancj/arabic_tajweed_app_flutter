import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

void main() {
  const matcher = TracingMatcher();
  const pen = 24.0;

  final shape = TracingShapeSvg.parse(
    File('assets/svg/alphabet/ba_base.svg').readAsStringSync(),
    id: 'ba',
  );
  final base = shape.resolve(const Size(328, 860), padding: 48).parts.first;
  final metric = base.paths.first.computeMetrics().first;
  final random = Random(11);

  List<Offset> trace({Offset shift = Offset.zero, double jitter = 4}) => [
    for (var d = 0.0; d < metric.length; d += 2)
      metric.getTangentForOffset(d)!.position +
          shift +
          Offset(
            (random.nextDouble() - .5) * jitter,
            (random.nextDouble() - .5) * jitter,
          ),
  ];

  TracingMatchResult match(List<Offset> points, {double? penWidth}) =>
      matcher.match(
        target: base,
        strokes: [
          DrawingStroke(
            points: points,
            color: const Color(0xFF000000),
            width: pen,
          ),
        ],
        penWidth: penWidth,
      );

  test('линия буквы тоньше пера — допуск считается от пера', () {
    // Перо 24px против линии буквы ~14px: центр штриха может отойти,
    // при этом штрих по-прежнему полностью накрывает букву.
    expect(base.strokeWidth, lessThan(pen));

    final drifted = trace(shift: const Offset(-3, -8));

    expect(match(drifted, penWidth: pen).isMatch, isTrue);
    expect(
      match(drifted).isMatch,
      isFalse,
      reason: 'без учёта пера тот же штрих отвергался',
    );
  });

  test('сдвиг больше пера не проходит', () {
    expect(
      match(trace(shift: const Offset(-7, -18)), penWidth: pen).isMatch,
      isFalse,
    );
  });

  test('толстое перо не пропускает неверную форму', () {
    final height = base.paths.first.getBounds().height;
    List<Offset> spiked(double amount) => [
      for (var d = 0.0; d < metric.length; d += 2)
        () {
          final t = d / metric.length;
          final p = metric.getTangentForOffset(d)!.position;
          return Offset(
            p.dx,
            p.dy - exp(-pow((t - .5) / .13, 2)) * height * amount,
          );
        }(),
    ];

    for (final amount in [0.35, 0.45, 0.6]) {
      final result = match(spiked(amount), penWidth: pen);
      expect(result.isMatch, isFalse, reason: 'пик $amount: $result');
    }
  });
}
