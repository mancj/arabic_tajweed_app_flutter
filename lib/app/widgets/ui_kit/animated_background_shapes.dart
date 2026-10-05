import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/drifting_rotation.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tilt/flutter_tilt.dart';

/// Фоновые фигуры карточек: тихое вращение, появление и параллакс.
class AnimatedBackgroundShapes extends StatefulWidget {
  const AnimatedBackgroundShapes({super.key});

  @override
  State<AnimatedBackgroundShapes> createState() =>
      _AnimatedBackgroundShapesState();
}

class _AnimatedBackgroundShapesState extends State<AnimatedBackgroundShapes> {
  // Выбранный узор сохраняется при ответе и смене темы, а не загружается заново.
  late final (String, String) _shape = [
    UIImages.background_shape_1,
    UIImages.background_shape_2,
    UIImages.background_shape_3,
  ].shuffled().first;

  @override
  Widget build(BuildContext context) {
    final still = kIsWeb || MediaQuery.disableAnimationsOf(context);
    const curve = Curves.easeInOut;
    const scaleFactor = 0.8;
    const parallaxOffset1 = -16.0;
    const parallaxOffset2 = -8.0;
    const parallaxOffset3 = -1.0;

    Widget layer(String asset, bool back) {
      final image = Image.asset(
        asset,
        fit: BoxFit.cover,
        color: UIColors.backgroundShapes2,
      );
      if (still) return image;
      return DriftingRotation(
            duration: Duration(milliseconds: back ? 3000 : 3600),
            period: Duration(seconds: back ? 5 : 6),
            child: image,
          )
          .animate()
          .fadeIn(duration: .5.seconds)
          .scaleXY(
            begin: back ? .9 : 1.1,
            end: 1,
            duration: Duration(milliseconds: back ? 800 : 600),
            curve: curve,
          );
    }

    Widget parallax(double offset, Widget child) => still
        ? child
        : TiltParallax(offset: Offset(offset, offset), child: child);

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: scaleFactor,
          child: parallax(parallaxOffset1, layer(_shape.$2, true)),
        ),
        Transform.scale(
          scale: scaleFactor,
          child: parallax(parallaxOffset2, layer(_shape.$1, false)),
        ),
        parallax(
          parallaxOffset3,
          Container(
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
