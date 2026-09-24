import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Полноэкранное поле точек, мимо которых зритель как будто летит вперёд.
///
/// Частицы поднимаются, ускоряются и становятся крупнее по мере приближения.
/// Их положение считается из одних общих часов, поэтому виджет не создаёт
/// отдельный контроллер для каждой точки.
class StarfieldWidget extends StatefulWidget {
  const StarfieldWidget({
    super.key,
    this.particleCount = 54,
    this.color,
    this.speed = 1,
    this.seed = 19,
    this.minRadius = 0.8,
    this.maxRadius = 2.2,
    this.particleLifetime,
  }) : assert(particleCount >= 0),
       assert(speed > 0),
       assert(minRadius > 0),
       assert(minRadius <= maxRadius),
       assert(particleLifetime == null || particleLifetime >= Duration.zero);

  final int particleCount;
  final Color? color;
  final double speed;
  final int seed;
  final double minRadius;
  final double maxRadius;

  /// Полное время жизни поля, включая плавное исчезновение в конце.
  /// Null оставляет бесконечную анимацию, как раньше.
  final Duration? particleLifetime;

  @override
  State<StarfieldWidget> createState() => _StarfieldWidgetState();
}

class _StarfieldWidgetState extends State<StarfieldWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onFrame);
  final _frame = ValueNotifier<_StarfieldFrame>(
    const _StarfieldFrame(clock: 0, age: 0),
  );
  Duration _lastTick = Duration.zero;
  late List<_Star> _stars = _buildStars();

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onFrame(Duration elapsed) {
    final delta = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    final previous = _frame.value;
    _frame.value = _StarfieldFrame(
      clock: previous.clock + delta * widget.speed,
      age: previous.age + delta,
    );
  }

  @override
  void didUpdateWidget(StarfieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seed != oldWidget.seed ||
        widget.particleCount != oldWidget.particleCount) {
      _stars = _buildStars();
    }
  }

  List<_Star> _buildStars() {
    final random = math.Random(widget.seed);

    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);

    return List.generate(
      widget.particleCount,
      (_) => _Star(
        x: between(0.04, 0.96),
        phase: random.nextDouble(),
        duration: between(3.2, 7.2),
        size: random.nextDouble(),
        drift: between(-0.045, 0.045),
        opacity: between(0.38, 1),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _StarfieldPainter(
          stars: _stars,
          frame: _frame,
          color: widget.color ?? UIColors.text,
          minRadius: widget.minRadius,
          maxRadius: widget.maxRadius,
          particleLifetime: widget.particleLifetime,
        ),
      ),
    );
  }
}

class _StarfieldFrame {
  const _StarfieldFrame({required this.clock, required this.age});

  final double clock;
  final double age;
}

class _Star {
  const _Star({
    required this.x,
    required this.phase,
    required this.duration,
    required this.size,
    required this.drift,
    required this.opacity,
  });

  final double x;
  final double phase;
  final double duration;
  final double size;
  final double drift;
  final double opacity;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({
    required this.stars,
    required this.frame,
    required this.color,
    required this.minRadius,
    required this.maxRadius,
    required this.particleLifetime,
  }) : super(repaint: frame);

  final List<_Star> stars;
  final ValueListenable<_StarfieldFrame> frame;
  final Color color;
  final double minRadius;
  final double maxRadius;
  final Duration? particleLifetime;

  static const _fadeOutDuration = 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    final currentFrame = frame.value;
    final lifetime = particleLifetime?.inMicroseconds;
    final lifetimeOpacity = lifetime == null
        ? 1.0
        : (1 -
                  (currentFrame.age -
                          lifetime / Duration.microsecondsPerSecond +
                          _fadeOutDuration) /
                      _fadeOutDuration)
              .clamp(0.0, 1.0);
    if (lifetimeOpacity <= 0) return;

    final paint = Paint()..isAntiAlias = true;

    for (final star in stars) {
      final progress = (currentFrame.clock / star.duration + star.phase) % 1;
      final approach = Curves.easeInCubic.transform(progress);
      final edgeFade = math
          .min(progress / 0.08, (1 - progress) / 0.12)
          .clamp(0.0, 1.0);
      final horizontalDrift =
          star.drift * math.sin(math.pi * progress) * size.width;
      final x = star.x * size.width + horizontalDrift;
      final y = size.height * (1.08 - 1.16 * approach);
      final baseRadius = minRadius + (maxRadius - minRadius) * star.size;
      final radius = baseRadius * (0.42 + 1.5 * approach);

      paint.color = color.withValues(
        alpha: color.a * star.opacity * edgeFade * lifetimeOpacity,
      );
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) =>
      oldDelegate.stars != stars ||
      oldDelegate.frame != frame ||
      oldDelegate.color != color ||
      oldDelegate.minRadius != minRadius ||
      oldDelegate.maxRadius != maxRadius ||
      oldDelegate.particleLifetime != particleLifetime;
}
