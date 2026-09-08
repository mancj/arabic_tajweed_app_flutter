import 'dart:async';

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
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:collection/collection.dart';

class LetterWidgetCard extends StatelessWidget {
  static const _shape = SmoothBorderRadius.all(
    SmoothRadius(cornerRadius: 24, cornerSmoothing: 1),
  );

  /// Подъём узора над серединой строки. Строка ужата до кегля, а буква
  /// сидит в ней не по центру: у Scheherazade запас под базовой линией
  /// больше, чем над верхом буквы. Разницу и выбирает этот подъём.
  ///
  /// Считается от строки, а не от чернил конкретной буквы: чернила у ث и ج
  /// лежат по-разному, и кольцо прыгало бы при каждой смене.
  static const _decorRise = -6.0;

  final String letter;
  final String? question;
  final String? labelText;
  final bool isArabic;

  /// Подпись под буквой внутри кольца: «в конце», «в середине» — где
  /// стоит показанная форма. Не задана — под буквой пусто.
  final String? subtitle;

  /// Нажатие на кнопку воспроизведения. Не задан — кнопки нет: у слогов
  /// и понятий записи пока не существует, и мёртвая кнопка врёт.
  final VoidCallback? onPlay;

  /// Звучащая запись — на неё реагирует волна внизу карточки.
  /// Подписан только сам виджет волны, карточка на позицию не перестраивается.
  final ValueListenable<AudioTrack>? track;

  /// Чем озвучивать букву самой: авто-звук всегда играет с начала, тогда
  /// как нажатие звучащую букву останавливает. Не задан — берётся [onPlay].
  final VoidCallback? onAutoPlay;

  /// Проигрывать ли букву самой, без нажатия. Показ карточки — это и есть
  /// знакомство с буквой, и звук здесь ждать нечего. Выключается там,
  /// где звук помешал бы: например, в задании на слух.
  final bool autoPlay;

  /// Показывать ли кнопку звучания. В задании та же карточка задаёт вопрос
  /// про букву, и озвучка была бы подсказкой — там кнопку прячут вместе
  /// с автоматическим звучанием.
  final bool showPlay;

  const LetterWidgetCard({
    super.key,
    required this.letter,
    required this.isArabic,
    this.question,
    this.labelText,
    this.subtitle,
    this.onPlay,
    this.onAutoPlay,
    this.track,
    this.autoPlay = true,
    this.showPlay = true,
  });

  /// Есть ли на карточке звучание. Волна внизу — это дорожка кнопки,
  /// и без кнопки она обещала бы звук, которого не будет.
  bool get _playable => showPlay && onPlay != null;

  /// Голый [Tilt] без контейнера: коробка карточки не поворачивается и не
  /// получает ни блика, ни бегающей тени. Виджет нужен только как источник
  /// прогресса для слоёв [TiltParallax] внутри — двигаются буква и фон.
  ///
  /// [TiltConfig.angle] здесь не участвует: без контейнера поворот никто
  /// не применяет, а параллакс считается от положения указателя.
  static const _tiltConfig = TiltConfig(
    enableGestureTouch: false,
    enableReverse: false,
    leaveCurve: Curves.easeOutCubic,
    leaveDuration: Duration(milliseconds: 1500),
    sensorFactor: 3,
    sensorRevertFactor: .02,
  );

  @override
  Widget build(BuildContext context) {
    return Tilt(
      tiltConfig: _tiltConfig,
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
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
        // Высоту карточки задаёт контент. Узор на неё не влияет: он живёт
        // в боксе буквы и вылезает за него через [OverflowBox], а по краям
        // карточки его подрезает [ClipRRect].
        // Узор занимает квадрат в ширину экрана: карточка растянута на всю
        // страницу, а лишнее всё равно подрезается. Ширину самой карточки
        // дал бы [LayoutBuilder], но он тут вреден: перестройки внутри него,
        // включая тики анимаций узора, выполняются в его layout, тот всплывает
        // до вьюпорта, а [SingleChildScrollView] на каждом layout загоняет
        // позицию в границы — и пружина у края пропадает.
        child: Builder(
          builder: (context) {
            final decorSide = MediaQuery.sizeOf(context).width;

            return ClipRRect(
              borderRadius: _shape,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_playable)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: WaveformWidget(
                        color: UIColors.orange,
                        height: 100,
                        layers: 3,
                        track: track,
                        restHeight: .55,
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
                                  BadgeLabel(
                                    text: labelText!,
                                    color: UIColors.ink,
                                  ),
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
                        const Margin.vertical(16),
                        _glyph(decorSide),
                        if (_playable) ...[
                          const Margin.vertical(56),
                          _PlayControl(
                            letter: letter,
                            onTap: onPlay!,
                            onAutoPlay: onAutoPlay,
                            track: track,
                            autoPlay: autoPlay,
                          ),
                        ] else
                          const Margin.vertical(32),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Буква вместе с узором: узор лежит в её боксе и центруется по нему,
  /// поэтому остаётся вокруг буквы, куда бы ту ни поставила раскладка
  /// карточки. Размером узора распоряжается [side] — ширина карточки:
  /// [OverflowBox] снимает ограничение бокса, и квадрат узора выходит
  /// за букву во все стороны.
  Widget _glyph(double side) => SizedBox(
    height: 80,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(0, -_decorRise),
          child: OverflowBox(
            key: kDebugMode ? UniqueKey() : null,
            maxWidth: side,
            maxHeight: side,
            child: SizedBox.square(dimension: side, child: _backgroundShapes()),
          ),
        ),
        // Глиф уезжает за наклоном сильнее фона — так буква
        // отделяется от подложки и кажется ближе к зрителю.
        Positioned(
          bottom: 16,
          child: TiltParallax(
            offset: const Offset(8, 8),
            // Смена буквы — своя анимация, а не только появление карточки:
            // в уроке карточка остаётся на месте и меняется лишь глиф,
            // и без этого он просто подменялся.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: .8, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: Container(
                decoration: ShapeDecoration(
                  shape: const OvalBorder(),
                  shadows: [
                    BoxShadow(
                      offset: const Offset(2, 2),
                      blurRadius: 16,
                      spreadRadius: 8,
                      color: UIColors.cardBackground.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                child: Text(
                  letter,
                  key: ValueKey(letter),
                  style: TextStyle(
                    fontSize: isArabic ? 80 : 32,
                    // Строка ужата до кегля: иначе высоту бокса задаёт шрифт,
                    // и у каждой буквы свой запас сверху и снизу.
                    height: 1,

                    fontFamily: isArabic
                        ? UITextStyles.fontScheherazadeNew
                        : UITextStyles.fontSerif,
                    color: UIColors.ink,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (subtitle != null)
          Positioned(
            bottom: -12,
            child: TiltParallax(
              offset: const Offset(8, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal:3, vertical: 0),
                decoration:  BoxDecoration(
                  color: UIColors.cardBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle!,
                  key: ValueKey(subtitle),
                  style: UITextStyles.serifSemibold18.copyWith(color: UIColors.orange),
                ).animate().fadeIn(duration: .3.seconds),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _backgroundShapes() {
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
        Opacity(
          opacity: .13,
          child: Transform.scale(
            scale: scaleFactor,
            child: TiltParallax(
              offset: const Offset(parallaxOffset1, parallaxOffset1),
              child:
                  DriftingRotation(
                        child: Image.asset(shape.$2, fit: BoxFit.cover),
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
        ),
        Opacity(
          opacity: .1,
          child: Transform.scale(
            scale: scaleFactor,
            child: TiltParallax(
              offset: const Offset(parallaxOffset2, parallaxOffset2),
              child:
                  DriftingRotation(
                        duration: const Duration(milliseconds: 3600),
                        period: const Duration(seconds: 6),
                        child: Image.asset(shape.$1, fit: BoxFit.cover),
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
        ),
        Opacity(
          opacity: 1,
          child: TiltParallax(
            offset: const Offset(parallaxOffset3, parallaxOffset3),
            child: Container(
              width: scaleFactor * 100,
              height: scaleFactor * 100,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: UIColors.black.withValues(alpha: .1),
                    width: 1,
                  ),
                ),
                color: UIColors.cardBackground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Кнопка звучания: на ходу показывает остановку, в остальное время —
/// воспроизведение. Слушает запись сама, чтобы карточка не перестраивалась
/// на каждый кадр волны.
///
/// Она же заводит автоматическое звучание: буква звучит при появлении
/// карточки и при каждой смене глифа — состояние нужно только для этого.
class _PlayControl extends StatefulWidget {
  const _PlayControl({
    required this.letter,
    required this.onTap,
    required this.autoPlay,
    this.onAutoPlay,
    this.track,
  });

  final String letter;
  final VoidCallback onTap;
  final VoidCallback? onAutoPlay;
  final ValueListenable<AudioTrack>? track;
  final bool autoPlay;

  @override
  State<_PlayControl> createState() => _PlayControlState();
}

class _PlayControlState extends State<_PlayControl> {
  /// Пауза перед автоматическим звучанием: карточка успевает выехать
  /// и показать букву, и только потом её называют.
  static const _autoPlayDelay = Duration(milliseconds: 300);

  Timer? _autoPlay;

  @override
  void initState() {
    super.initState();
    _scheduleAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _PlayControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // В уроке карточка нередко остаётся на месте, а меняется только глиф —
    // для звука это такое же появление буквы, как и новая карточка.
    if (oldWidget.letter != widget.letter) _scheduleAutoPlay();
  }

  void _scheduleAutoPlay() {
    _autoPlay?.cancel();
    if (!widget.autoPlay) return;
    _autoPlay = Timer(_autoPlayDelay, () {
      if (mounted) (widget.onAutoPlay ?? widget.onTap)();
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.track;
    if (listenable == null) return _button(false);

    return ValueListenableBuilder<AudioTrack>(
      valueListenable: listenable,
      builder: (_, value, _) => _button(value.isPlaying),
    );
  }

  Widget _button(bool isPlaying) => Column(
    children: [
      CircleButton(
        size: 46,
        onTap: widget.onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: 24,
            color: UIColors.white,
          ),
        ),
      ),
      const Margin.vertical(8),
      SizedBox(
        width: 100,
        child: Text(
          isPlaying
              ? 'Нажмите, чтобы остановить'
              : 'Нажмите, чтобы воспроизвести',
          textAlign: TextAlign.center,
          style: UITextStyles.regular10.copyWith(
            height: 1.1,
            color: UIColors.secondary3,
          ),
        ),
      ),
    ],
  );
}
