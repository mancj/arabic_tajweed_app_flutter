import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/badge_label.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/drifting_rotation.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/waveform_widget.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LetterWidgetCard extends StatelessWidget {
  static const _shape = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: 24, cornerSmoothing: 1),
  );

  final String letter;
  final String? question;
  final String? labelText;

  /// Нажатие на кнопку воспроизведения. Не задан — кнопки нет: у слогов
  /// и понятий записи пока не существует, и мёртвая кнопка врёт.
  final VoidCallback? onPlay;

  /// Звучащая запись — на неё реагирует волна внизу карточки.
  /// Подписан только сам виджет волны, карточка на позицию не перестраивается.
  final ValueListenable<AudioTrack>? track;

  const LetterWidgetCard({
    super.key,
    required this.letter,
    this.question,
    this.labelText,
    this.onPlay,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UIColors.cardBackground,
        borderRadius: _shape,
        border: Border.all(color: UIColors.white.withValues(alpha: .3)),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: WaveformWidget(
                height: 80,
                layers: 3,
                track: track,
                restHeight: .75,
                minBumps: 3,
                maxBumps: 4,
                // minBumpWidth: 0.015,
                // maxBumpWidth: 0.3,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (labelText != null || question != null)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (labelText != null)
                            BadgeLabel(text: labelText!, color: UIColors.ink),
                          if (question != null) ...[
                            const Margin.vertical(8),
                            Text(
                              question!,
                              style: UITextStyles.cardTitle.copyWith(
                                color: UIColors.ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  Transform.translate(
                    offset: const Offset(0, 32),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 80,
                        fontFamily: UITextStyles.fontScheherazadeNew,
                        color: UIColors.ink,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const Margin.vertical(56),
                  if (onPlay != null) ...[
                    CircleButton(
                      size: 46,
                      onTap: onPlay,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 24,
                        color: UIColors.white,
                      ),
                    ),
                    const Margin.vertical(8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Нажмите, чтобы воспроизвести',
                        textAlign: TextAlign.center,
                        style: UITextStyles.regular10.copyWith(
                          height: 1.1,
                          color: UIColors.secondary3,
                        ),
                      ),
                    ),
                  ],
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
    const scaleFactor = 1.0;

    return Opacity(
      opacity: .3,
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scaleFactor,
              child:
                  DriftingRotation(
                        minAngle: -40,
                        maxAngle: 40,
                        child: Image.asset(
                          UIImages.background_shape_1_1,
                          fit: BoxFit.cover,
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
            Transform.scale(
              scale: scaleFactor * 0.92,
              child:
                  DriftingRotation(
                        minAngle: -20,
                        maxAngle: 20,
                        duration: const Duration(milliseconds: 3600),
                        period: const Duration(seconds: 6),
                        child: Image.asset(
                          UIImages.background_shape_1_2,
                          fit: BoxFit.cover,
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
      ),
    );
  }
}
