import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../resources/ui_resources.dart';

/// Бегущая волна из пар светящихся точек с тонкими перемычками.
///
/// Точки задерживаются в раздвинутом положении и сходятся в капсулу.
/// Один контроллер перерисовывает только холст, без пересборки виджета.
class GlowWaveWidget extends StatefulWidget {
  const GlowWaveWidget({
    super.key,
    this.width = 320,
    this.height = 96,
    this.pairCount = 11,
    this.amplitude = 24,
    this.period = const Duration(milliseconds: 1750),
    this.color,
    this.glowIntensity = 1,
    this.glowSpread = 1,
    this.lineWidth = .6,
    this.playing = true,
  }) : assert(width > 0 && width < double.infinity),
       assert(height > 0 && height < double.infinity),
       assert(pairCount > 0),
       assert(amplitude >= 0 && amplitude < double.infinity),
       assert(glowIntensity >= 0 && glowIntensity < double.infinity),
       assert(glowSpread >= 0 && glowSpread < double.infinity),
       assert(lineWidth >= 0 && lineWidth < double.infinity),
       assert(period > Duration.zero);

  final double width;
  final double height;
  final int pairCount;

  /// Расстояние от середины до каждой точки в раскрытой паре.
  final double amplitude;
  final Duration period;
  final Color? color;

  /// Сила ореола: 1 — базовая яркость, 0 — без свечения.
  final double glowIntensity;

  /// Размер ореола относительно базового. 0 отключает свечение.
  final double glowSpread;

  /// Толщина перемычек в логических пикселях при базовом размере; 0 скрывает их.
  final double lineWidth;

  /// Пауза сохраняет положение; продолжение не начинает цикл заново.
  final bool playing;

  @override
  State<GlowWaveWidget> createState() => _GlowWaveWidgetState();
}

class _GlowWaveWidgetState extends State<GlowWaveWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.period,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _motionEnabled = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncPlayback();
  }

  @override
  void didUpdateWidget(GlowWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.stop();
      _controller.duration = widget.period;
    }
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  void _syncPlayback() {
    if (widget.playing && _motionEnabled && _foreground) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQuery.platformBrightnessOf(context);
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _GlowWavePainter(
            animation: _controller,
            pairCount: widget.pairCount,
            amplitude: widget.amplitude,
            color: widget.color ?? UIColors.text,
            glowIntensity: widget.glowIntensity,
            glowSpread: widget.glowSpread,
            lineWidth: widget.lineWidth,
          ),
        ),
      ),
    );
  }
}

class _GlowWavePainter extends CustomPainter {
  _GlowWavePainter({
    required this.animation,
    required this.pairCount,
    required this.amplitude,
    required this.color,
    required this.glowIntensity,
    required this.glowSpread,
    required this.lineWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final int pairCount;
  final double amplitude;
  final Color color;
  final double glowIntensity;
  final double glowSpread;
  final double lineWidth;

  // Соседняя пара повторяет движение примерно через 220 мс при базовом темпе.
  static const _phaseStep = .125;

  double _opening(double phase) {
    if (phase < .12) return 0;
    if (phase < .48) {
      return Curves.easeOutCubic.transform((phase - .12) / .36);
    }
    if (phase < .64) return 1;
    if (phase < .84) {
      return 1 - Curves.easeInOutCubic.transform((phase - .64) / .20);
    }
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0) return;
    final scale = math.min(
      1.0,
      math.min(size.width / (pairCount * 25), size.height / 32),
    );
    // Оставляем место широкому ореолу, чтобы он не обрезался у края холста.
    final edge = math.min(
      math.min(size.width, size.height) / 2,
      16 * scale * math.max(1, glowSpread),
    );
    final step = pairCount == 1
        ? 0.0
        : (size.width - edge * 2) / (pairCount - 1);
    final maxGap = math.min(amplitude, math.max(0.0, size.height / 2 - edge));
    final minGap = math.min(3.2 * scale, maxGap);
    final centerY = size.height / 2;
    final dots = Path();
    final lines = Path();

    for (var i = 0; i < pairCount; i++) {
      final phase = (animation.value - i * _phaseStep + .03) % 1;
      final opening = _opening(phase);
      final gap = minGap + (maxGap - minGap) * opening;
      final radius = (3 - 1.3 * opening) * scale;
      final x = pairCount == 1 ? size.width / 2 : edge + i * step;
      final top = Offset(x, centerY - gap);
      final bottom = Offset(x, centerY + gap);
      lines.moveTo(top.dx, top.dy);
      lines.lineTo(bottom.dx, bottom.dy);

      dots.addOval(Rect.fromCircle(center: top, radius: radius));
      dots.addOval(Rect.fromCircle(center: bottom, radius: radius));
      if (gap < radius * 2.4) {
        dots.addPath(_mergedPair(x, centerY, gap, radius), Offset.zero);
      }
    }

    if (lineWidth > 0) {
      canvas.drawPath(
        lines,
        Paint()
          ..color = color.withValues(alpha: color.a * .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth * scale,
      );
    }
    if (glowIntensity > 0 && glowSpread > 0) {
      final glowScale = scale * glowSpread;
      // Размываем расширенный контур: у маленькой точки обычное размытие
      // заливки почти теряет яркость и не даёт заметного ореола.
      canvas.drawPath(
        dots,
        Paint()
          ..color = color.withValues(
            alpha: color.a * (.38 * glowIntensity).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * glowScale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.8 * glowScale),
      );
      canvas.drawPath(
        dots,
        Paint()
          ..color = color.withValues(
            alpha: color.a * (.75 * glowIntensity).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * glowScale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * glowScale),
      );
    }
    canvas.drawPath(dots, Paint()..color = color);
  }

  /// Перед разрывом у капсулы сужается середина, как у двух капель.
  Path _mergedPair(double x, double y, double gap, double radius) {
    final separation = ((gap / radius - 1) / 1.4).clamp(0.0, 1.0);
    final angle = separation * math.pi / 2;
    final side = radius * math.cos(angle);
    final neck = side * (1 - Curves.easeInOut.transform(separation));
    final joinY = math.max(0.0, gap - radius * math.sin(angle));
    final shoulder = joinY * .55;
    return Path()
      ..moveTo(x + side, y - joinY)
      ..cubicTo(x + side, y - shoulder, x + neck, y - shoulder, x + neck, y)
      ..cubicTo(
        x + neck,
        y + shoulder,
        x + side,
        y + shoulder,
        x + side,
        y + joinY,
      )
      ..lineTo(x - side, y + joinY)
      ..cubicTo(x - side, y + shoulder, x - neck, y + shoulder, x - neck, y)
      ..cubicTo(
        x - neck,
        y - shoulder,
        x - side,
        y - shoulder,
        x - side,
        y - joinY,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_GlowWavePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.pairCount != pairCount ||
      oldDelegate.amplitude != amplitude ||
      oldDelegate.color != color ||
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.glowSpread != glowSpread ||
      oldDelegate.lineWidth != lineWidth;
}
