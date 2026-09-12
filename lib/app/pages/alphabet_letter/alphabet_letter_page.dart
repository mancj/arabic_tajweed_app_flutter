import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';

import 'alphabet_letter_controller.dart';

export 'alphabet_letter_binding.dart';
export 'alphabet_letter_controller.dart';

/// Экран знакомства с буквой алфавита (макет Tajweed, node 1:61).
///
/// Карточки с фиксированной внутренней раскладкой (основная и карточки форм)
/// свёрстаны в масштабе от макетной ширины — так пропорции сохраняются
/// на экранах уже, чем 440pt, под которые нарисован макет.
class AlphabetLetterPage extends GetView<AlphabetLetterController> {
  static const routeName = '/alphabet_letter';

  const AlphabetLetterPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Алфавит',
      bottomBar: NextButton(
        title: controller.nextTitle,
        subtitle: controller.nextSubtitle,
        onTap: controller.onNext,
      ),
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: Column(
          children: [
            LessonProgressBar(value: controller.progress),
            const Margin.vertical(16),
            _LetterCard(
              label: controller.label,
              glyph: controller.glyph,
              name: controller.name,
              transcription: controller.transcription,
            ),
            const Margin.vertical(16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final form in controller.forms) ...[
                  if (form != controller.forms.first)
                    const Margin.horizontal(8),
                  Expanded(child: _FormCard(form: form)),
                ],
              ],
            ),
            const Margin.vertical(12),
            _PronunciationCard(onTap: controller.onPlay),
            const Margin.vertical(12),
            _TajweedCard(
              title: controller.tajweedTitle,
              text: controller.tajweedText,
            ),
          ],
        ),
      ),
    );
  }
}

/// Основная карточка с крупной буквой на прописной сетке.
class _LetterCard extends StatelessWidget {
  final String label;
  final String glyph;
  final String name;
  final String transcription;

  /// Высота карточки в макете.
  static const _height = 366.0;

  const _LetterCard({
    required this.label,
    required this.glyph,
    required this.name,
    required this.transcription,
  });

  @override
  Widget build(BuildContext context) {
    return LetterCard(
      designHeight: _height,
      builder: (context, k) => [
        Positioned(
          top: 25 * k,
          left: 0,
          right: 0,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: UITextStyles.scaled(
              UITextStyles.medium15,
              k,
            ).copyWith(color: UIColors.secondary2),
          ),
        ),
        Positioned(
          top: 91 * k,
          left: 0,
          right: 0,
          height: LetterGuides.designHeight * k,
          child: Center(child: LetterGuides(k: k)),
        ),
        // Строка поднята над сеткой прописи: арабские глифы сидят
        // в нижней части строки, и по центру сетки буква уходит вниз.
        // При таком смещении контур буквы попадает в макетные 109…215.
        Positioned(
          top: 22.5 * k,
          left: 0,
          right: 0,
          height: LetterGuides.designHeight * k,
          child: Center(
            child: Text(
              glyph,
              textAlign: TextAlign.center,
              style: UITextStyles.arabicRegular(133.5 * k),
            ),
          ),
        ),
        Positioned(
          top: 266 * k,
          left: 0,
          right: 0,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: UITextStyles.scaled(UITextStyles.semibold22, k),
          ),
        ),
        Positioned(
          top: 327 * k,
          left: 0,
          right: 0,
          child: Text(
            transcription,
            textAlign: TextAlign.center,
            style: UITextStyles.scaled(UITextStyles.serifRegular17, k),
          ),
        ),
      ],
    );
  }
}

/// Карточка одной позиционной формы буквы.
class _FormCard extends StatelessWidget {
  final LetterForm form;

  static const _width = 125.625;
  static const _height = 150.75;

  const _FormCard({required this.form});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final k = constraints.maxWidth / _width;

        return Container(
          height: _height * k,
          decoration: SquircleBorders.squircleBorder(
            color: UIColors.highlightArea,
            borderRadius: 16,
            borderSide: BorderSide(color: UIColors.borders, width: 0.6),
            shadows: [
              BoxShadow(
                color: UIColors.shadows,
                offset: Offset(0, 3),
                blurRadius: 1.5,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 14.65 * k,
                top: 38.7 * k,
                width: 97.36 * k,
                height: 60.72 * k,
                child: SvgPicture.asset(
                  UISVGAssets.letterFormStroke,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                top: 8 * k,
                left: 0,
                right: 0,
                height: 103 * k,
                child: Center(
                  child: Text(
                    form.glyph,
                    textAlign: TextAlign.center,
                    style: UITextStyles.arabicMedium(
                      50.4 * k,
                    ).copyWith(color: UIColors.secondary1),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 8,
                right: 8,
                child: Text(
                  form.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UITextStyles.regular10Compact.copyWith(
                    color: UIColors.secondary1,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 4,
                child: Text(
                  '${form.index}',
                  style: UITextStyles.playfairMedium14.copyWith(
                    color: UIColors.secondary1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PronunciationCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PronunciationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.highlightArea,
        borderRadius: 16,
        borderSide: BorderSide(color: UIColors.borders, width: 0.6),
        shadows: [
          BoxShadow(
            color: UIColors.shadows,
            offset: Offset(0, 4),
            blurRadius: 1.95,
          ),
        ],
      ),
      child: Row(
        children: [
          AppGestureDetector(
            child: CircleButton(
              child: Icon(
                Icons.play_arrow_rounded,
                color: UIColors.highlightArea,
                size: 24,
              ),
            ),
          ),
          const Margin.horizontal(8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Произношение', style: UITextStyles.regular17),
                Margin.vertical(4),
                Text(
                  'Нажмите, чтобы прослушать',
                  style: UITextStyles.regular13.copyWith(
                    color: UIColors.secondary2,
                  ),
                ),
              ],
            ),
          ),
          const Margin.horizontal(8),
          SvgPicture.asset(UISVGAssets.waveform, width: 38, height: 19),
        ],
      ),
    );
  }
}

class _TajweedCard extends StatelessWidget {
  final String title;
  final String text;

  const _TajweedCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.highlightArea,
        borderRadius: 16,
        borderSide: BorderSide(color: UIColors.borders, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: UITextStyles.playfairBold18),
          const Margin.vertical(24),
          Text(text, style: UITextStyles.playfairMedium18),
        ],
      ),
    );
  }
}
