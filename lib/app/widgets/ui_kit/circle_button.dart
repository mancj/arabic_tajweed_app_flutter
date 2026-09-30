import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';

class CircleButton extends StatelessWidget {
  final double size;
  final Gradient? gradient;
  final Color? borderColor;
  final bool showBorder;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  final Widget? child;
  final VoidCallback? onTap;
  final bool hapticOnTap;

  /// Кнопка «удерживайте»: см. [AppGestureDetector.onPressStart].
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  const CircleButton({
    super.key,
    this.onTap,
    this.hapticOnTap = true,
    this.onPressStart,
    this.onPressEnd,
    this.size = 42,
    this.showBorder = true,
    this.borderWidth = 1,
    this.child,
    this.gradient,
    this.borderColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      hapticOnTap: hapticOnTap,
      onPressStart: onPressStart,
      onPressEnd: onPressEnd,
      pressedOpacity: .94,
      child: Container(
        width: size,
        height: size,
        padding: showBorder ? EdgeInsets.all(borderWidth) : EdgeInsets.zero,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              gradient ??
              LinearGradient(
                colors: [UIColors.primary, UIColors.circleButtonBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
          border: showBorder
              ? Border.all(
                  color: borderColor ?? UIColors.white30,
                  width: borderWidth,
                )
              : null,
          boxShadow:
              boxShadow ??
              [
                BoxShadow(
                  color: UIColors.shadows,
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        ),
        child: child,
      ),
    );
  }
}
