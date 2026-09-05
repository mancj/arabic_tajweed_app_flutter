import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_stroke.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

/// Части соединённых форм ـحـ, ـضـ, ـطـ состоят из двух линий с разрывом
/// в 60–114 пикселей. Провести их можно по-разному: с какой начать, в какую
/// сторону вести каждую и отрывать ли перо на переходе. Все эти способы —
/// одна и та же буква, и узнаваться должны все.
void main() {
  const matcher = TracingMatcher();
  final rnd = Random(7);

  List<Offset> pointsOf(Path path, {double jitter = 3}) => [
    for (final metric in path.computeMetrics())
      for (var d = 0.0; d <= metric.length; d += 6)
        metric.getTangentForOffset(d)!.position +
            Offset(
              (rnd.nextDouble() - .5) * jitter,
              (rnd.nextDouble() - .5) * jitter,
            ),
  ];

  DrawingStroke stroke(List<Offset> points) =>
      DrawingStroke(points: points, color: const Color(0xFF000000), width: 14);

  ResolvedTracingPart partOf(String name) {
    final shape = TracingShapeSvg.parse(
      File('assets/svg/alphabet/$name.svg').readAsStringSync(),
      id: name,
    );
    return shape
        .resolve(const Size(329, 329))
        .parts
        .firstWhere((part) => part.paths.length >= 2);
  }

  bool matches(ResolvedTracingPart part, List<DrawingStroke> strokes) => matcher
      .match(target: part, strokes: strokes, penWidth: 14, structural: true)
      .isMatch;

  const names = [
    'hha_mid',
    'dod_mid',
    'to_mid',
    'kaf_mid',
    'lam_mid',
    'mim_mid',
    'ha_mid',
    'kaf_base',
  ];

  test('часть из двух линий узнаётся, как её ни проведи', () {
    for (final name in names) {
      final part = partOf(name);
      final a = pointsOf(part.paths[0]);
      final b = pointsOf(part.paths[1]);

      final ways = {
        'по штриху': [stroke(a), stroke(b)],
        'в обратном порядке': [stroke(b), stroke(a)],
        'одним росчерком': [
          stroke([...a, ...b]),
        ],
        'одним, второй с конца': [
          stroke([...a, ...b.reversed]),
        ],
        'тремя кусками': [
          stroke(a),
          stroke(b.sublist(0, b.length ~/ 2)),
          stroke(b.sublist(b.length ~/ 2)),
        ],
      };

      ways.forEach((way, strokes) {
        expect(matches(part, strokes), isTrue, reason: '$name, $way');
      });
    }
  });

  /// Перебор способов расширяет то, что признаётся буквой, — проверяем,
  /// что не до всего подряд.
  ///
  /// Кяф здесь не участвует: его вторая линия — чёрточка внутри буквы
  /// длиной 82 при 318 у всей части. На неё приходится четверть точек
  /// сигнатуры, и её порча одна не вытягивает расхождение за порог. Так
  /// было и до перебора эталонов: спрямлённая чёрточка давала 0.036 при
  /// пороге 0.08. Судить такую мелочь можно только по месту на холсте,
  /// а не по форме — этим занимается непрерывный режим с покрытием.
  test('перебор способов не пропускает чужую форму', () {
    for (final name in names.where((name) => name != 'kaf_base')) {
      final part = partOf(name);
      final a = pointsOf(part.paths[0]);
      final b = pointsOf(part.paths[1]);
      final box = part.bounds;

      // Вторая линия заменена прямой между её концами: длина и место те же,
      // формы нет.
      final flattened = [
        for (var i = 0; i < b.length; i++)
          Offset.lerp(b.first, b.last, i / (b.length - 1))!,
      ];
      // Вторая линия отражена по вертикали внутри своего кадра: чаша
      // становится куполом.
      final flipped = [
        for (final p in b) Offset(p.dx, box.top + box.bottom - p.dy),
      ];

      expect(
        matches(part, [stroke(a)]),
        isFalse,
        reason: '$name: одна линия из двух — ещё не буква',
      );
      expect(
        matches(part, [stroke(a), stroke(flattened)]),
        isFalse,
        reason: '$name: вторая линия спрямлена',
      );
      expect(
        matches(part, [stroke(a), stroke(flipped)]),
        isFalse,
        reason: '$name: вторая линия перевёрнута',
      );
    }
  });
}
