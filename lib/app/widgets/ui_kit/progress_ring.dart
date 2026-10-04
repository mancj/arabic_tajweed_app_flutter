import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/widgets/ui_kit/orbital_rings_widget.dart';
import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../margin.dart';

/// Кольцо освоенности: при нуле показывает только начало пути.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.semanticLabel,
    this.size = 112,
    this.revealFraction = 1,
    super.key,
  });

  final double value;
  final String semanticLabel;
  final double size;
  final double revealFraction;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic,
          builder: (context, animated, child) {
            final visibleProgress = animated * revealFraction.clamp(0.0, 1.0);
            return CustomPaint(
              painter: _RingPainter(
                value: visibleProgress,
                trackColor: UIColors.borders,
                progressColor: UIColors.primary,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    top: 10,
                    child: OverflowBox(
                      maxHeight: 220,
                      maxWidth: 220,
                      child: OrbitalRingsWidget(
                        color: UIColors.backgroundShapes1,
                        thickness: 1.1,
                        dashThickness: 1.5,
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: size,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(visibleProgress * 100).round()}%',
                          style: UITextStyles.semibold20,
                        ),
                        const Margin.vertical(4),
                        Text(
                          'ОСВОЕНО',
                          style: UITextStyles.monoSemibold11.copyWith(
                            color: UIColors.text.withValues(alpha: .72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.trackColor,
    required this.progressColor,
  });

  final double value;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final circle = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * value;

    canvas.drawArc(
      circle,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (value == 0) {
      final marker = Offset(center.dx, center.dy - radius);
      canvas.drawCircle(
        marker,
        stroke,
        Paint()..color = progressColor.withValues(alpha: .16),
      );
      canvas.drawCircle(marker, stroke / 2, Paint()..color = progressColor);
      return;
    }

    canvas.drawArc(
      circle,
      start,
      sweep,
      false,
      Paint()
        ..color = progressColor.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      circle,
      start,
      sweep,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      value != oldDelegate.value ||
      trackColor != oldDelegate.trackColor ||
      progressColor != oldDelegate.progressColor;
}
