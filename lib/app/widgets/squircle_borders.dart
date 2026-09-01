import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';

/// Скруглённые углы «как в Figma»: непрерывная кривая вместо дуги окружности.
class SquircleBorders {
  static ShapeDecoration squircleBorder({
    Color? color,
    double borderRadius = 24.0,
    double cornerSmoothing = 1.0,
    BorderSide borderSide = BorderSide.none,
    List<BoxShadow>? shadows,
  }) {
    return ShapeDecoration(
      color: color ?? UIColors.white,
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius(
          cornerRadius: borderRadius,
          cornerSmoothing: cornerSmoothing,
        ),
        side: borderSide,
      ),
      shadows: shadows,
    );
  }
}
