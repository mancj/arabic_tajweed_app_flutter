import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Поворачивает ребёнка на случайный угол из диапазона
/// [minAngle]..[maxAngle] — и раз в [period] выбирает новый.
///
/// Угол задаётся в градусах (-360..360), а не в оборотах: так его проще
/// читать глазами. Конкретный угол каждый раз новый, поэтому фигура не
/// выглядит заведённой на один и тот же поворот — она тихо дышит, пока
/// карточка на экране.
class DriftingRotation extends StatefulWidget {
  final Widget child;

  /// Границы угла в градусах. Равные значения — строго заданный поворот.
  final double minAngle;
  final double maxAngle;

  /// Сколько длится один доворот.
  final Duration duration;

  /// Как часто выбирается новый угол. Меньше [duration] ставить смысла нет:
  /// фигура не успеет доехать.
  final Duration period;

  final Curve curve;

  /// Сид случайности. Задан — последовательность углов повторяема
  /// (нужно тестам и золотым скриншотам).
  final int? seed;

  const DriftingRotation({
    super.key,
    required this.child,
    this.minAngle = -20,
    this.maxAngle = 20,
    this.duration = const Duration(seconds: 3),
    this.period = const Duration(seconds: 5),
    this.curve = Curves.easeInOut,
    this.seed,
  });

  @override
  State<DriftingRotation> createState() => _DriftingRotationState();
}

class _DriftingRotationState extends State<DriftingRotation> {
  late final math.Random _random = math.Random(widget.seed);
  late double _angle = _nextAngle();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(DriftingRotation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.period, (_) => _turn());
    // Первый доворот — сразу после появления: фигура въезжает в кадр
    // уже в движении, а не замирает до конца первого периода.
    WidgetsBinding.instance.addPostFrameCallback((_) => _turn());
  }

  void _turn() {
    if (!mounted) return;
    setState(() => _angle = _nextAngle());
  }

  double _nextAngle() =>
      widget.minAngle +
      _random.nextDouble() * (widget.maxAngle - widget.minAngle);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: _angle / 360,
      duration: widget.duration,
      curve: widget.curve,
      child: widget.child,
    );
  }
}
