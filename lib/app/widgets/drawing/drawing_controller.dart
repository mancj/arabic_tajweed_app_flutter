import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  DrawingController({
    Color color = Colors.black,
    double strokeWidth = 26,
    double smoothing = 0.35,
    double minDistance = 3,
  })  : _color = color,
        _strokeWidth = strokeWidth,
        _smoothing = smoothing.clamp(0.05, 1.0),
        _minDistance = minDistance;

  final double _smoothing;
  final double _minDistance;

  final List<DrawingStroke> _strokes = [];
  final List<Offset> _currentPoints = [];

  Color _color;
  double _strokeWidth;
  Offset? _filtered;
  Offset? _raw;
  TracingChecker? _checker;

  late final List<DrawingStroke> _strokesView = UnmodifiableListView(_strokes);
  late final List<Offset> _currentPointsView = UnmodifiableListView(_currentPoints);

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

  void endStroke() {
    if (_currentPoints.isEmpty) return;

    _catchUp();

    _strokes.add(DrawingStroke(
      points: List.of(_currentPoints),
      color: _color,
      width: _strokeWidth,
    ));
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
  /// теряет непокрытый хвост буквы. Догоняем тем же фильтром, поэтому
  /// стык остаётся гладким.
  void _catchUp() {
    final target = _raw;
    if (target == null) return;

    var point = _filtered ?? _currentPoints.last;
    for (var i = 0; i < 64 && (point - target).distance > 0.5; i++) {
      point = _step(point, target);
      if ((point - _currentPoints.last).distance >= math.max(_minDistance, 0.5)) {
        _currentPoints.add(point);
      }
    }

    if ((target - _currentPoints.last).distance > 0.5) {
      _currentPoints.add(target);
    }
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
