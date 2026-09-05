import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

/// Обводка по видимому контуру должна засчитываться, хотя ведут её волной
/// и перелетают за хвост.
///
/// Тест идёт через настоящий холст, а не через матчер напрямую: и полоса
/// измерения шире линии, и сглаживание в контроллере срезает углы — всё
/// это меняет метрики. Замеренный запас на та-в-конце (линия 17px):
///
///     волна 12px → покрытие 100%, точность 100%, отклонение 0.57
///     волна 14px → покрытие 100%, точность 100%, отклонение 0.62
///     волна 16px → покрытие  99%, точность 100%, отклонение 0.67 — промах
///
/// То есть обводка проходит, пока центр пера гуляет примерно на 0.8
/// толщины линии буквы. Стережём границу: 12px — тот случай, на котором
/// пришла жалоба, и он обязан засчитываться.
void main() {
  /// Обводка пальцем: низкочастотная волна поперёк линии плюс перелёт
  /// за конец — так выглядит настоящий штрих, а не выборка по эталону.
  List<Offset> tracedAlong(Path path, {required double wobble}) {
    final metric = path.computeMetrics().first;
    final end = metric.length * 1.08;
    final phase = Random(3).nextDouble() * pi;

    return [
      for (var d = 0.0; d <= end; d += 4)
        () {
          final tangent = metric.getTangentForOffset(min(d, metric.length))!;
          final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
          final overshoot = max(0.0, d - metric.length);
          return tangent.position +
              normal * (sin(d / 40 + phase) * wobble) +
              tangent.vector * overshoot;
        }(),
    ];
  }

  testWidgets('обведённая по контуру буква засчитывается', (tester) async {
    final shape = TracingShapeSvg.parse(
      File('assets/svg/alphabet/ta_end.svg').readAsStringSync(),
      id: 'ta_end',
    );

    ResolvedTracingPart? completed;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 329,
            height: 329,
            child: DrawingCanvas(
              placeholder: shape,
              placeholderPadding: 0,
              onPartCompleted: (part) => completed = part,
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(DrawingCanvas));
    final resolved = shape.resolve(box.size);
    final points = tracedAlong(resolved.parts.first.paths.first, wobble: 12);

    final gesture = await tester.startGesture(points.first + box.topLeft);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point + box.topLeft);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      completed?.id,
      resolved.parts.first.id,
      reason: 'основа обведена по контуру, но холст её не засчитал',
    );
  });
}
