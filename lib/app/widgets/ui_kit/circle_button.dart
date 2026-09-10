import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';

class CircleButton extends StatelessWidget {
  final double size;
  final Color color;
  final bool showBorder;
  final double borderWidth;

  final Widget? child;
  final VoidCallback? onTap;

  /// Кнопка «удерживайте»: см. [AppGestureDetector.onPressStart].
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  const CircleButton({
    super.key,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.size = 42,
    this.color = UIColors.primary,
    this.showBorder = true,
    this.borderWidth = 1,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      onPressStart: onPressStart,
      onPressEnd: onPressEnd,
      pressedOpacity: .94,
      child: Container(
        width: size,
        height: size,
        padding: showBorder ? EdgeInsets.all(borderWidth) : EdgeInsets.zero,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [UIColors.primary, UIColors.circleButtonBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: showBorder
              ? Border.all(
                  color: UIColors.circleButtonBottom,
                  width: borderWidth,
                )
              : null,
          boxShadow: const [
            BoxShadow(
              color: UIColors.circleButtonShadow,
              spreadRadius: 1,
              blurRadius: 8,

              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
