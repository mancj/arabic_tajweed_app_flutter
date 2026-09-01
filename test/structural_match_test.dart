import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

void main() {
  const matcher = TracingMatcher();
  final shape = TracingShapeSvg.parse(
      File('assets/svg/alphabet/ba_base.svg').readAsStringSync(), id: 'ba');
  final base = shape.resolve(const Size(328, 700), padding: 48).parts.first;
  final metric = base.paths.first.computeMetrics().first;
  final bounds = base.paths.first.getBounds();
  final random = Random(9);

  /// Обводка основы с искажениями: растяжение по осям, сдвиг, дрожь,
  /// пик вверх посередине и обрыв на части длины.
  List<Offset> draw({
    double stretchX = 1,
    double stretchY = 1,
    double scale = 1,
    Offset shift = Offset.zero,
    double jitter = 0,
    double bump = 0,
    double portion = 1,
  }) {
    final end = metric.length * portion;
    return [
      for (var d = 0.0; d < end; d += 2)
        () {
          final t = d / metric.length;
          final p = metric.getTangentForOffset(d)!.position;
          final spiked =
              Offset(p.dx, p.dy - exp(-pow((t - .5) / .13, 2)) * bounds.height * bump);
          return Offset(
                bounds.center.dx + (spiked.dx - bounds.center.dx) * stretchX * scale,
                bounds.center.dy + (spiked.dy - bounds.center.dy) * stretchY * scale,
              ) +
              shift +
              Offset((random.nextDouble() - .5) * jitter,
                  (random.nextDouble() - .5) * jitter);
        }(),
    ];
  }

  TracingMatchResult match(List<Offset> points) => matcher.match(
        target: base,
        strokes: [
          DrawingStroke(points: points, color: const Color(0xFF000000), width: 24),
        ],
        penWidth: 24,
        structural: true,
      );

  test('форма важнее пропорций', () {
    final cases = {
      'вдвое уже': draw(stretchX: 0.5),
      'вдвое шире': draw(stretchX: 2),
      'вдвое ниже': draw(stretchY: 0.5),
      'вдвое выше': draw(stretchY: 2),
      'перекошенная и дрожащая': draw(stretchX: 0.7, stretchY: 1.4, jitter: 10),
      'мельче и в стороне': draw(scale: 0.5, shift: const Offset(-60, 80)),
    };

    for (final entry in cases.entries) {
      final result = match(entry.value);
      expect(result.isMatch, isTrue, reason: '${entry.key}: $result');
    }
  });

  test('неверная форма не проходит даже при верных пропорциях', () {
    final cases = {
      'пик вверх посередине': draw(bump: 0.35),
      'половина основы': draw(portion: 0.5),
      'три четверти': draw(portion: 0.75),
      'прямая линия': [for (var i = 0; i < 60; i++) Offset(60.0 + i * 3, 300)],
      'круг': [
        for (var i = 0; i <= 60; i++)
          Offset(160 + 80 * cos(i / 60 * 2 * pi), 300 + 80 * sin(i / 60 * 2 * pi)),
      ],
    };

    for (final entry in cases.entries) {
      final result = match(entry.value);
      expect(result.isMatch, isFalse, reason: '${entry.key}: $result');
    }
  });

  test('размер всё же ограничен: каракуля не проходит', () {
    expect(match(draw(scale: 0.08)).isMatch, isFalse);
    expect(match(draw(scale: 5)).isMatch, isFalse);
  });

  test('направление обводки не важно', () {
    final forward = draw();
    final backward = forward.reversed.toList();
    expect(match(backward).isMatch, isTrue);
    expect(match(backward).shapeError, closeTo(match(forward).shapeError, 0.001));
  });

  test('основу можно нарисовать двумя штрихами в любом порядке', () {
    final points = draw();
    final left = points.sublist(0, points.length ~/ 2);
    final right = points.sublist(points.length ~/ 2);

    DrawingStroke strokeOf(List<Offset> p) =>
        DrawingStroke(points: p, color: const Color(0xFF000000), width: 24);

    for (final order in [
      [left, right],
      [right, left],
    ]) {
      final result = matcher.match(
        target: base,
        strokes: [for (final piece in order) strokeOf(piece)],
        penWidth: 24,
        structural: true,
      );
      expect(result.isMatch, isTrue, reason: '$result');
    }
  });
}
