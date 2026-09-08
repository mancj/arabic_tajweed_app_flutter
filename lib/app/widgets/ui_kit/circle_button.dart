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

  const CircleButton({
    super.key,
    this.onTap,
    this.size = 42,
    this.color = UIColors.orange,
    this.showBorder = true,
    this.borderWidth = 1,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      pressedOpacity: .94,
      child: Container(
        width: size,
        height: size,
        padding: showBorder ? EdgeInsets.all(borderWidth) : EdgeInsets.zero,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [UIColors.orange, UIColors.orangeLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: showBorder
              ? Border.all(color: UIColors.orangeLight, width: borderWidth)
              : null,
          boxShadow: const [
            BoxShadow(
              color: UIColors.cardShadow,
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
