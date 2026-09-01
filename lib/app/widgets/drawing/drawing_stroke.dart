import 'dart:ui';

/// Один непрерывный штрих — от касания пальцем до отрыва.
class DrawingStroke {
  /// Сглаженные точки штриха в локальных координатах холста.
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  bool get isDot => points.length < 2;

  DrawingStroke copyWith({List<Offset>? points, Color? color, double? width}) =>
      DrawingStroke(
        points: points ?? this.points,
        color: color ?? this.color,
        width: width ?? this.width,
      );

  /// Промежуточное состояние между двумя штрихами с одинаковым числом точек —
  /// нужно для анимации слияния с фигурой.
  static DrawingStroke lerp(DrawingStroke a, DrawingStroke b, double t) {
    if (a.points.length != b.points.length) return t < 0.5 ? a : b;
    return DrawingStroke(
      points: [
        for (var i = 0; i < a.points.length; i++)
          Offset.lerp(a.points[i], b.points[i], t)!,
      ],
      color: Color.lerp(a.color, b.color, t) ?? b.color,
      width: lerpDouble(a.width, b.width, t) ?? b.width,
    );
  }

  Rect get bounds {
    var left = points.first.dx;
    var top = points.first.dy;
    var right = left;
    var bottom = top;
    for (final p in points) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
      if (p.dy < top) top = p.dy;
      if (p.dy > bottom) bottom = p.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(width / 2);
  }

  /// Путь штриха, построенный сплайном Catmull-Rom: линия проходит
  /// ровно через все точки, но без изломов на стыках.
  Path toPath() {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 1) {
      // Точка-касание: рисуем нулевой отрезок, круглый cap даст кружок.
      path.lineTo(points.first.dx, points.first.dy);
      return path;
    }

    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }
}
