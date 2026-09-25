import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../app_gesture_detector.dart';

/// Небольшое текстовое действие с моноширинной подписью.
class MonoTextButton extends StatelessWidget {
  const MonoTextButton({
    required this.title,
    required this.onPressed,
    this.icon,
    this.color,
    super.key,
  });

  final String title;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? UIColors.primary;
    final icon = this.icon;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: title,
      excludeSemantics: true,
      child: IgnorePointer(
        ignoring: onPressed == null,
        child: Opacity(
          opacity: onPressed == null ? .5 : 1,
          child: AppGestureDetector(
            onTap: onPressed,
            pressedOpacity: .96,
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: UITextStyles.monoRegular14.copyWith(
                      color: foreground,
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
