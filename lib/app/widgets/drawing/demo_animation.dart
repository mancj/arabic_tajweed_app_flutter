import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'tracing_shape.dart';

/// Показ: холст сам обводит часть поверх контура, чтобы человек увидел,
/// с чего начинать и куда вести. Живёт три доли — пишет, держит написанное
/// и растворяется, см. [TracingDemo]: без последних двух дорисованная буква
/// осталась бы лежать в полную силу и была бы неотличима от чернил человека.
///
/// Когда показ уместен, решает холст; здесь только само движение.
/// Слушатели дёргаются на каждом кадре и при запуске или остановке.
class DemoAnimation extends ChangeNotifier {
  DemoAnimation({required TickerProvider vsync})
    : _controller = AnimationController(vsync: vsync) {
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;

  ResolvedTracingShape? _shape;
  int _from = 0;
  double _gap = 0;
  bool _disposed = false;

  bool get isPlaying => _shape != null;

  /// Обводит части [shape] начиная с [from]: собранные заново не показываем.
  /// [gap] — пауза между частями в длине показа, [speed] — пикселей пера
  /// в секунду. Длительность своя на каждую часть, от её длины.
  void play(
    ResolvedTracingShape shape, {
    required int from,
    required double gap,
    required double speed,
    double? strokeWidth,
  }) {
    final length = shape.traceLength(
      strokeWidth: strokeWidth,
      from: from,
      gap: gap,
    );
    final drawing = (length / speed * 1000).round().clamp(400, 4000);

    _shape = shape;
    _from = from;
    _gap = gap;
    notifyListeners();

    _controller
      ..duration = Duration(
        milliseconds: (drawing / TracingDemo.drawing).round(),
      )
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (!_disposed && _controller.isCompleted) stop();
      });
  }

  void stop() {
    if (_shape == null) return;
    _controller.stop();
    _shape = null;
    notifyListeners();
  }

  /// Рисует показ между контуром и чернилами: поверх подсказки, под рукой.
  void paint(
    Canvas canvas, {
    required Color color,
    required Curve curve,
    double? strokeWidth,
  }) {
    final shape = _shape;
    if (shape == null) return;
    final t = _controller.value;
    shape.paintTrace(
      canvas,
      color.withValues(alpha: TracingDemo.opacity(t)),
      TracingDemo.traced(t, curve: curve),
      strokeWidth: strokeWidth,
      from: _from,
      gap: _gap,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }
}
