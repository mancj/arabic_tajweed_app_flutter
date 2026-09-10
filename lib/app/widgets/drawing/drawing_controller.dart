import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';

import 'drawing_stroke.dart';
import 'tracing_matcher.dart';

/// Хранит нарисованные штрихи и сглаживает входящие точки пальца.
///
/// Сглаживание в два этапа:
/// 1. [_smoothing] — экспоненциальный фильтр, гасит дрожание пальца;
/// 2. [_minDistance] — прореживание слишком близких точек, чтобы сплайн
///    не «звенел» на месте.
/// Итоговая кривая строится сплайном Catmull-Rom в [DrawingStroke.toPath].
class DrawingController extends ChangeNotifier {
  /// [smoothing] — доля пути до пальца, которую линия проходит за одно
  /// событие: 1 — идёт точно за пальцем и повторяет каждое его дрожание,
  /// 0.3 — заметно сглаживает, а отставание закрывает догон в [endStroke].
  /// Значение по умолчанию одно на все холсты: пробовали 1 в уроке ради
  /// отзывчивости, линия при обводке выходила рваной; 0.5 всё ещё дрожала.
  /// [minDistance] — ближе этого (в пикселях) точки не кладутся.
  ///
  /// Толщины здесь нет намеренно: её знает только [DrawingCanvas], потому
  /// что перо масштабируется вместе с фигурой при раскладке.
  DrawingController({
    Color color = UIColors.text,
    double smoothing = 0.3,
    double minDistance = 3,
  }) : assert(
         smoothing > 0 && smoothing <= 1,
         'smoothing — доля от 0 до 1, а не пиксели',
       ),
       assert(minDistance >= 0),
       _color = color,
       _smoothing = smoothing,
       _minDistance = minDistance;

  final double _smoothing;
  final double _minDistance;

  /// Насколько хвосту позволено отвернуть от траектории штриха.
  static const _maxTailTurn = math.pi / 4;

  final List<DrawingStroke> _strokes = [];
  final List<Offset> _currentPoints = [];

  Color _color;

  /// Ставится холстом из [DrawingCanvas._syncPen]. До первой раскладки
  /// штрихи рисуются этой заглушкой.
  double _strokeWidth = 1;
  Offset? _filtered;
  Offset? _raw;
  TracingChecker? _checker;

  late final List<DrawingStroke> _strokesView = UnmodifiableListView(_strokes);
  late final List<Offset> _currentPointsView = UnmodifiableListView(
    _currentPoints,
  );

  /// Завершённые штрихи.
  List<DrawingStroke> get strokes => _strokesView;

  /// Штрих, который рисуется прямо сейчас (null, если палец не на экране).
  DrawingStroke? get currentStroke => _currentPoints.isEmpty
      ? null
      : DrawingStroke(
          points: _currentPointsView,
          color: _color,
          width: _strokeWidth,
        );

  bool get isEmpty => _strokes.isEmpty && _currentPoints.isEmpty;

  bool get isDrawing => _currentPoints.isNotEmpty;

  Color get color => _color;

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    notifyListeners();
  }

  double get strokeWidth => _strokeWidth;

  set strokeWidth(double value) {
    if (_strokeWidth == value) return;
    _strokeWidth = value;
    notifyListeners();
  }

  /// Проверку выполняет [DrawingCanvas]: только он знает, как фигура
  /// вписана в текущий размер холста.
  void attachChecker(TracingChecker checker) => _checker = checker;

  void detachChecker(TracingChecker checker) {
    if (identical(_checker, checker)) _checker = null;
  }

  /// Сверяет нарисованное с фигурой-подсказкой. При совпадении холст
  /// запускает анимацию слияния штрихов с фигурой.
  TracingMatchResult check() =>
      _checker?.call() ??
      const TracingMatchResult.empty(TracingMatchStatus.noShape);

  void startStroke(Offset point) {
    _currentPoints
      ..clear()
      ..add(point);
    _filtered = point;
    _raw = point;
    notifyListeners();
  }

  void extendStroke(Offset point) {
    if (_currentPoints.isEmpty) {
      startStroke(point);
      return;
    }

    _raw = point;

    final previous = _filtered ?? _currentPoints.last;
    final smoothed = _step(previous, point);
    _filtered = smoothed;

    if ((smoothed - _currentPoints.last).distance < _minDistance) return;

    _currentPoints.add(smoothed);
    notifyListeners();
  }

  /// Завершает штрих. [at] — место, где палец оторвали: оно идёт сразу
  /// в догон и не подмешивается в фильтр обычным движением, иначе подворот
  /// пальца успевал бы попасть в линию до всякого сглаживания.
  void endStroke([Offset? at]) {
    if (_currentPoints.isEmpty) return;

    if (at != null) _raw = at;
    _catchUp();

    _strokes.add(
      DrawingStroke(
        points: List.of(_currentPoints),
        color: _color,
        width: _strokeWidth,
      ),
    );
    _currentPoints.clear();
    _filtered = null;
    _raw = null;
    notifyListeners();
  }

  /// Доводит хвост штриха до места, где палец оторвали.
  ///
  /// Фильтр всегда отстаёт от пальца, и чем сильнее сглаживание, тем больше
  /// отставание: при `smoothing = 0.1` это десятки пикселей. Без догона штрих
  /// обрывается раньше времени — на глаз это заметно, а проверка обводки
  /// теряет непокрытый хвост буквы.
  ///
  /// Хвост кладётся равными шагами, а не затухающими, как раньше: у самого
  /// конца точки сгущались, и сплайн, оценивая касательную по соседям
  /// разной длины, загибал линию крючком. И поворот хвоста ограничен:
  /// отрывая палец, человек его подворачивает, событие «вверх» приходит
  /// в стороне от траектории — этот подворот и был изломом на конце.
  void _catchUp() {
    final target = _raw;
    if (target == null) return;

    final from = _currentPoints.last;
    final step = math.max(_minDistance, 0.5);
    final tail = _clampTurn(from, target);

    final distance = (tail - from).distance;
    if (distance < step) return;

    final steps = math.max(1, (distance / step).round());
    for (var i = 1; i <= steps; i++) {
      _currentPoints.add(Offset.lerp(from, tail, i / steps)!);
    }
  }

  /// Не даёт хвосту отвернуть от траектории больше чем на [_maxTailTurn].
  /// Длина сохраняется: догон нужен именно чтобы закрыть отставание фильтра.
  Offset _clampTurn(Offset from, Offset to) {
    final delta = to - from;
    final distance = delta.distance;
    final direction = _tailDirection();
    if (distance <= 0 || direction == null) return to;

    final unit = delta / distance;
    final dot = unit.dx * direction.dx + unit.dy * direction.dy;
    if (dot >= math.cos(_maxTailTurn)) return to;

    // Сторону поворота задаёт знак векторного произведения.
    final cross = direction.dx * unit.dy - direction.dy * unit.dx;
    final angle = cross >= 0 ? _maxTailTurn : -_maxTailTurn;
    final rotated = Offset(
      direction.dx * math.cos(angle) - direction.dy * math.sin(angle),
      direction.dx * math.sin(angle) + direction.dy * math.cos(angle),
    );
    return from + rotated * distance;
  }

  /// Куда штрих шёл перед отрывом. Плечо берём не по двум последним точкам:
  /// на такой длине дрожание руки заметнее самого движения.
  Offset? _tailDirection() {
    final last = _currentPoints.last;
    final span = math.max(_minDistance * 3, 12.0);

    for (var i = _currentPoints.length - 2; i >= 0; i--) {
      final delta = last - _currentPoints[i];
      if (delta.distance >= span) return delta / delta.distance;
    }

    final delta = last - _currentPoints.first;
    return delta.distance > 0 ? delta / delta.distance : null;
  }

  Offset _step(Offset from, Offset to) => Offset(
    from.dx + (to.dx - from.dx) * _smoothing,
    from.dy + (to.dy - from.dy) * _smoothing,
  );

  void cancelStroke() {
    if (_currentPoints.isEmpty) return;
    _currentPoints.clear();
    _filtered = null;
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    if (isEmpty) return;
    _strokes.clear();
    _currentPoints.clear();
    _filtered = null;
    notifyListeners();
  }
}
