import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_controller.dart';

/// Отрывая палец, человек его подворачивает: событие «вверх» приходит
/// в стороне от траектории. Хвост штриха должен это сглаживать, иначе
/// на конце линии остаётся излом.
void main() {
  /// Наибольший угол между соседними отрезками штриха, в градусах.
  double sharpestTurn(List<Offset> points) {
    var worst = 0.0;
    for (var i = 2; i < points.length; i++) {
      final a = points[i - 1] - points[i - 2];
      final b = points[i] - points[i - 1];
      if (a.distance == 0 || b.distance == 0) continue;
      final cosine = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
      worst = max(worst, acos(cosine.clamp(-1.0, 1.0)) * 180 / pi);
    }
    return worst;
  }

  /// Прямой штрих вправо, а палец отрывают в стороне от траектории.
  List<Offset> strokeWithRoll(Offset roll) {
    final controller = DrawingController(smoothing: .4, minDistance: 8);
    controller.startStroke(const Offset(0, 100));
    for (var x = 10.0; x <= 200; x += 10) {
      controller.extendStroke(Offset(x, 100));
    }
    controller.endStroke(const Offset(200, 100) + roll);
    return controller.strokes.single.points;
  }

  test('подворот пальца при отрыве не даёт излома', () {
    for (final roll in const [
      Offset(0, 30),
      Offset(0, -30),
      Offset(-20, 20),
      Offset(-30, 0),
    ]) {
      final turn = sharpestTurn(strokeWithRoll(roll));
      expect(
        turn,
        lessThanOrEqualTo(46),
        reason: 'отрыв со сдвигом $roll ломает линию на $turn°',
      );
    }
  });

  test('хвост всё ещё доводит линию до пальца', () {
    // Ровный отрыв по ходу движения — догон обязан закрыть отставание
    // фильтра целиком, иначе проверка обводки теряет конец буквы.
    final points = strokeWithRoll(const Offset(20, 0));
    expect((points.last - const Offset(220, 100)).distance, lessThan(1));
  });
}
