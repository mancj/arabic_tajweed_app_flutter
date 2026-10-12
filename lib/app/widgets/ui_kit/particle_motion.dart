import 'dart:math' as math;

/// Общая траектория маленьких точек над аудиоволной и кольцом прогресса.
abstract final class ParticleMotion {
  static double rise(double progress) =>
      1 - math.pow(1 - progress, 3).toDouble();

  static double drift(double progress) => math.sin(math.pi * progress);

  static double opacity({
    required double progress,
    required double duration,
    required double fadeInDuration,
  }) {
    final fadeIn = (progress * duration / fadeInDuration).clamp(0.0, 1.0);
    final fadeOut = ((1 - progress) / .28).clamp(0.0, 1.0);
    return fadeIn * fadeOut;
  }
}
