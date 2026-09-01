import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape.dart';

void main() {
  const matcher = TracingMatcher();

  /// Три точки треугольником, как у ش: две снизу, одна сверху посередине.
  final part = ResolvedTracingPart(
    id: 'dots',
    label: 'точки',
    paths: const [],
    dots: const [Offset(160, 220), Offset(200, 220), Offset(180, 180)],
    strokeWidth: 20,
    dotRadius: 10,
  );

  /// Габариты «уже собранной основы» — по ним меряется допустимый сдвиг.
  const letter = Rect.fromLTWH(80, 230, 200, 120);

  bool accepts(List<Offset> taps) {
    final strokes = [
      for (final tap in taps)
        DrawingStroke(points: [tap], color: const Color(0xFF000000), width: 20),
    ];
    final alignment = matcher.alignDots(
      target: part,
      strokes: strokes,
      penWidth: 20,
      reference: letter,
    );
    return matcher
        .match(
          target: part,
          strokes: strokes,
          alignment: alignment,
          penWidth: 20,
          structural: true,
        )
        .isMatch;
  }

  test('треугольник крупнее и мельче эталонного засчитывается', () {
    expect(accepts(const [Offset(150, 230), Offset(210, 230), Offset(180, 170)]),
        isTrue, reason: 'крупнее');
    expect(accepts(const [Offset(167, 213), Offset(193, 213), Offset(180, 187)]),
        isTrue, reason: 'мельче');
  });

  test('кривоватый треугольник и сдвинутая группа засчитываются', () {
    expect(accepts(const [Offset(157, 226), Offset(204, 216), Offset(183, 174)]),
        isTrue, reason: 'неровный');
    expect(accepts(const [Offset(178, 238), Offset(218, 238), Offset(198, 198)]),
        isTrue, reason: 'вся группа сдвинута');
  });

  test('ряд вместо треугольника не проходит', () {
    expect(accepts(const [Offset(150, 200), Offset(180, 200), Offset(210, 200)]),
        isFalse);
  });

  test('перевёрнутый треугольник не проходит', () {
    expect(accepts(const [Offset(160, 180), Offset(200, 180), Offset(180, 220)]),
        isFalse);
  });

  test('количество точек решающее', () {
    expect(accepts(const [Offset(160, 220), Offset(200, 220)]), isFalse,
        reason: 'две вместо трёх');
    expect(
        accepts(const [
          Offset(160, 220),
          Offset(200, 220),
          Offset(180, 180),
          Offset(180, 205),
        ]),
        isFalse,
        reason: 'четыре вместо трёх');
  });

  test('группа далеко от буквы не проходит', () {
    expect(accepts(const [Offset(160, 500), Offset(200, 500), Offset(180, 460)]),
        isFalse);
  });
}
