import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../app_gesture_detector.dart';
import '../margin.dart';

/// Небольшое текстовое действие с моноширинной подписью.
class MonoTextButton extends StatelessWidget {
  const MonoTextButton({
    required this.title,
    required this.onPressed,
    this.icon,
    this.color,
    super.key,
    this.padding,
  });

  final String title;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? UIColors.primary;
    final icon = this.icon;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: title,
      onTap: onPressed,
      excludeSemantics: true,
      child: IgnorePointer(
        ignoring: onPressed == null,
        child: Opacity(
          opacity: onPressed == null ? .5 : 1,
          child: AppGestureDetector(
            onTap: onPressed,
            pressedOpacity: .96,
            child: Padding(
              padding:
                  padding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const Margin.horizontal(8),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: UITextStyles.monoRegular14.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
