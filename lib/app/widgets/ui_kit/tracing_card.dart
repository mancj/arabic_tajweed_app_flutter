import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_card.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/waveform_widget.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_utils/src/extensions/num_extensions.dart';

/// Карточка обводки: шапка [LessonCard] с кнопкой «стереть», под ней
/// прописная сетка с холстом и строка обратной связи.
///
/// Одна и та же на уроке и на экране алфавита: холст, цвета слоёв, перо
/// и раскладка живут здесь, экраны отдают только заголовок, состояние
/// и обработчики. Контур под штрихами показывается или прячется —
/// это и есть разница между [TracingMode].
class TracingCard extends StatelessWidget {
  static const _actionButtonSize = 42.0;

  /// Кадр буквы — квадрат 329 из svg: в нём заложен запас под верхние
  /// и нижние точки. Сетка прописи ýже и ниже, она лежит внутри кадра;
  /// отступ до неё — из макета экрана знакомства с буквой.
  static const _frameHeight = 309.0;
  static const _guidesTop = 86.0;

  final String badge;
  final String title;

  /// Строка под сеткой: что рисовать дальше или что пошло не так.
  final String hint;

  final VoidCallback onClear;

  /// Звучание буквы через тот же плеер, что у остальных заданий.
  /// Если записи нет, кнопка не показывается.
  final VoidCallback? onPlay;
  final VoidCallback? onAutoPlay;
  final ValueListenable<AudioTrack>? track;
  final String? playbackKey;
  final bool autoPlay;

  final DrawingController controller;

  /// Один и тот же матчер у холста и у подсказок — иначе пороги разъедутся.
  final TracingMatcher matcher;
  final TracingMode mode;
  final TracingShape? shape;

  /// После принятого ответа холст остаётся виден, но больше не рисует.
  final bool enabled;

  /// См. [DrawingCanvas.missesBeforeReveal].
  final int missesBeforeReveal;

  final ValueChanged<TracingProgress>? onProgress;
  final ValueChanged<TracingMatchResult>? onChecked;
  final VoidCallback? onReveal;
  final VoidCallback? onMerged;

  const TracingCard({
    required this.badge,
    required this.title,
    required this.hint,
    required this.onClear,
    required this.controller,
    required this.matcher,
    required this.mode,
    required this.shape,
    required this.missesBeforeReveal,
    this.enabled = true,
    this.onPlay,
    this.onAutoPlay,
    this.track,
    this.playbackKey,
    this.autoPlay = true,
    this.onProgress,
    this.onChecked,
    this.onReveal,
    this.onMerged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LessonCard(
      badge: badge,
      title: title,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPlay case final play?) ...[
            PlayControl(
              letter: playbackKey ?? title,
              onTap: play,
              onAutoPlay: onAutoPlay,
              track: track,
              autoPlay: autoPlay,
              size: _actionButtonSize,
              showHint: false,
            ),
            const Margin.horizontal(8),
          ],
          _ClearButton(onTap: onClear),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final k = constraints.maxWidth / LetterGuides.designWidth;

          return SizedBox(
            height: (_frameHeight + 24) * k,
            // Волна должна доходить до внешнего края карточки. [LessonCard]
            // добавляет внутреннее поле 16 px, поэтому здесь компенсируем
            // его с трёх сторон и разрешаем слою выйти за границы Stack.
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (onPlay != null)
                  Positioned(
                    left: -16,
                    right: -16,
                    bottom: -16,
                    height: 100,
                    child: IgnorePointer(
                      child: WaveformWidget(
                        strokeWidth: .5,
                        height: 200,
                        layers: 3,
                        track: track,
                        restHeight: .4,
                        minBumps: 3,
                        maxBumps: 4,
                        particles: WaveformParticles(
                          minRadius: .5,
                          color: UIColors.primary,
                          maxRadius: 1,
                          duration: 1.seconds,
                          fadeInDuration: .2.seconds,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: _guidesTop * k,
                  left: 0,
                  right: 0,
                  height: LetterGuides.designHeight * k,
                  child: Center(child: LetterGuides(k: k)),
                ),
                Positioned.fill(
                  child: DrawingCanvas(
                    controller: controller,
                    matcher: matcher,
                    mode: mode,
                    placeholder: shape,
                    enabled: enabled,
                    // Четыре слоя, четыре цвета: контур под всем,
                    // поверх него показ, дальше чернила руки, и собранная
                    // буква вместо них, когда часть сошлась.
                    strokeWidth: 12,
                    placeholderPadding: 0,
                    missesBeforeReveal: missesBeforeReveal,
                    onProgress: onProgress,
                    onChecked: onChecked,
                    onReveal: onReveal,
                    onMerged: onMerged,
                  ),
                ),
                // Строка обратной связи лежит в свободном поле под сеткой,
                // внутри кадра буквы: своей строки под карточкой она не
                // стоит, а касания холсту не отбирает.
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: UITextStyles.monoRegular14.copyWith(
                        color: UIColors.secondary2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Стереть нарисованное и начать букву заново. Стоит в шапке карточки,
/// напротив заголовка: холст под ней занят целиком.
class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Стереть',
      child: CircleButton(
        size: TracingCard._actionButtonSize,
        onTap: onTap,
        child: Icon(
          CupertinoIcons.delete,
          size: 22,
          color: UIColors.primaryButtonText,
        ),
      ),
    );
  }
}
