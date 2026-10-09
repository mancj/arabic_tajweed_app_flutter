import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../resources/ui_resources.dart';
import '../../../widgets/ui_kit/next_button.dart';

/// Основное действие входа и выхода с состоянием ожидания и крупным шрифтом.
class AuthAction extends StatelessWidget {
  const AuthAction({
    required this.title,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
    this.neutralBackground = false,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;
  final bool neutralBackground;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: title,
    excludeSemantics: true,
    onTap: enabled ? onTap : null,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text =
            TextPainter(
              text: TextSpan(
                text: title,
                style: UITextStyles.semibold16Compact,
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
              maxWidth: math.max(1, constraints.maxWidth - (busy ? 60 : 0)),
            );
        final height = math.max(56.0, text.height + 24);
        text.dispose();
        return NextButton(
          title: title,
          height: height,
          enabled: enabled,
          glassProminent: !neutralBackground,
          neutralBackground: neutralBackground,
          leading: busy
              ? CupertinoActivityIndicator(
                  color: neutralBackground
                      ? UIColors.text
                      : UIColors.primaryButtonText,
                )
              : null,
          onTap: onTap,
        );
      },
    ),
  );
}
