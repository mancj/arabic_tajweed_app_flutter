import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LetterWidgetCard extends StatelessWidget {
  static const _shape = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: 24, cornerSmoothing: 1),
  );

  final String letter;
  const LetterWidgetCard({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UIColors.cardBackground,
        borderRadius: _shape,
        border: Border.all(color: UIColors.white),
        boxShadow: const [
          BoxShadow(
            color: UIColors.cardShadow,
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      // Высоту карточки задаёт контент (кружок с буквой); фоновая фигура
      // лежит в Positioned.fill, поэтому на размер не влияет — она лишь
      // растягивается по уже посчитанной коробке.
      child: ClipRRect(
        borderRadius: _shape,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              key: kDebugMode ? UniqueKey() : null,
              child: _backgroundShapes(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 100,
                      fontFamily: UITextStyles.fontScheherazadeNew,
                      color: UIColors.ink,
                    ),
                  ),
                  const Margin.vertical(16),
                  const CircleButton(
                    size: 52,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: UIColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backgroundShapes() {
    const curve = Curves.easeInOut;
    const scaleFactor = 1.5;

    return Opacity(
      opacity: .1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: scaleFactor,
            child: Image.asset(UIImages.background_shape_1_1, fit: BoxFit.cover)
                .animate()
                .fadeIn(duration: .5.seconds)
                .rotate(duration: 2.seconds, curve: curve, begin: .1, end: 0),
          ),
          Transform.scale(
            scale: scaleFactor * 0.8,
            child: Image.asset(UIImages.background_shape_1_2, fit: BoxFit.cover)
                .animate()
                .fadeIn(duration: .5.seconds)
                .rotate(duration: 2.seconds, curve: curve, begin: -.05, end: 0),
          ),
          Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: const ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(color: UIColors.black, width: 1),
              ),
              color: UIColors.cardBackground,
            ),
          ),
        ],
      ),
    );
  }
}
