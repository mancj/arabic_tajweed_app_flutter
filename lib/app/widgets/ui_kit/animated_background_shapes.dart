import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/drifting_rotation.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tilt/flutter_tilt.dart';

/// Фоновые фигуры карточек: тихое вращение, появление и параллакс.
class AnimatedBackgroundShapes extends StatelessWidget {
  const AnimatedBackgroundShapes({super.key});

  @override
  Widget build(BuildContext context) {
    const curve = Curves.easeInOut;
    const scaleFactor = 0.8;
    const parallaxOffset1 = -16.0;
    const parallaxOffset2 = -8.0;
    const parallaxOffset3 = -1.0;
    final (String, String) shape = [
      UIImages.background_shape_1,
      UIImages.background_shape_2,
    ].shuffled().first;

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: scaleFactor,
          child: TiltParallax(
            offset: const Offset(parallaxOffset1, parallaxOffset1),
            child:
                DriftingRotation(
                      child: Image.asset(
                        shape.$2,
                        fit: BoxFit.cover,
                        color: UIColors.backgroundShapes2,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: .5.seconds)
                    .scaleXY(
                      begin: 0.9,
                      end: 1,
                      duration: .8.seconds,
                      curve: curve,
                    ),
          ),
        ),
        Transform.scale(
          scale: scaleFactor,
          child: TiltParallax(
            offset: const Offset(parallaxOffset2, parallaxOffset2),
            child:
                DriftingRotation(
                      duration: const Duration(milliseconds: 3600),
                      period: const Duration(seconds: 6),
                      child: Image.asset(
                        shape.$1,
                        fit: BoxFit.cover,
                        color: UIColors.backgroundShapes2,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: .5.seconds)
                    .scaleXY(
                      begin: 1.1,
                      end: 1,
                      duration: .6.seconds,
                      curve: curve,
                    ),
          ),
        ),
        TiltParallax(
          offset: const Offset(parallaxOffset3, parallaxOffset3),
          child: Container(
            width: scaleFactor * 100,
            height: scaleFactor * 100,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(
                  color: UIColors.text.withValues(alpha: .1),
                  width: 1,
                ),
              ),
              color: UIColors.cardBackground,
            ),
          ),
        ),
      ],
    );
  }
}
