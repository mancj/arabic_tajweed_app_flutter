import 'dart:ui';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app_template/app/resources/ui_colors.dart';

class SquircleContainer extends StatelessWidget {
  final Widget child;

  const SquircleContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: UIColors.cardBackground,
        shape: SmoothRectangleBorder(
          side: const BorderSide(color: UIColors.white, width: 1.5),
          borderRadius: SmoothBorderRadius(
            cornerRadius: 14,
            cornerSmoothing: 1,
          ),
        ),
        shadows: const [
          BoxShadow(
            color: UIColors.cardShadow,
            blurStyle: BlurStyle.normal,
            offset: Offset(0, 2),
            blurRadius: 8
          )
        ],
        // shadows: [
        //   BoxShadow(
        //     color: UIColors.white.withOpacity(.7),
        //   ),
        //   const BoxShadow(color: Color(0xffF5F7FD), blurRadius: 12, spreadRadius: -12),
        // ],
      ),
      child: child,
    );
  }
}
