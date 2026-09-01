import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';

class CircleButton extends StatelessWidget {
  final double size;
  final Color color;
  final bool showBorder;
  final Color borderColor;
  final Widget? child;

  const CircleButton({
    super.key,
    this.size = 42,
    this.color = UIColors.teal,
    this.showBorder = true,
    this.borderColor = UIColors.tealDark,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: showBorder ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: child,
    );
  }
}
