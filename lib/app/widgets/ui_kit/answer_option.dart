import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Вариант ответа: радиокнопка, пунктирный разделитель и содержимое.
///
/// [accent] красит радиокнопку — им же подсвечивается верный и неверный
/// ответ после проверки.
class AnswerOption extends StatelessWidget {
  final Widget child;
  final bool selected;
  final Color? accent;
  final double playbackProgress;
  final double trailingPadding;
  final VoidCallback? onTap;

  const AnswerOption({
    required this.child,
    this.selected = false,
    this.accent,
    this.playbackProgress = 0,
    this.trailingPadding = 24,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: SquircleBorders.squircleBorder(
          color: UIColors.cardBackground,
          borderRadius: 18,
          borderSide: BorderSide(color: UIColors.borders),
          // Выбранный вариант в макете чуть приподнят над списком.
          shadows: selected
              ? [
                  BoxShadow(
                    color: UIColors.shadows,
                    offset: const Offset(0, 2),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: playbackProgress.clamp(0, 1),
                    heightFactor: 1,
                    child: ColoredBox(color: UIColors.primary10),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16, right: trailingPadding),
                child: Row(
                  children: [
                    _Radio(
                      selected: selected,
                      accent: accent ?? UIColors.primary,
                    ),
                    const Margin.horizontal(12),
                    RotatedBox(
                      quarterTurns: 1,
                      child: SvgPicture.asset(
                        UISVGAssets.dashedDivider,
                        width: 22,
                        colorFilter: ColorFilter.mode(
                          UIColors.borders,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const Margin.horizontal(12),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Звуковой вариант: динамик ближе к правому краю, но вся кнопка остаётся
/// доступной для нажатия. Увеличение отмечает именно звучащую запись.
class AudioAnswerOption extends StatelessWidget {
  const AudioAnswerOption({
    required this.label,
    required this.onTap,
    required this.onPlay,
    required this.isPlaying,
    this.selected = false,
    this.accent,
    this.playbackProgress = 0,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final bool isPlaying;
  final bool selected;
  final Color? accent;
  final double playbackProgress;

  @override
  Widget build(BuildContext context) => AnswerOption(
    selected: selected,
    accent: accent,
    playbackProgress: playbackProgress,
    trailingPadding: 8,
    onTap: onTap,
    child: Row(
      children: [
        Expanded(child: Text(label, style: UITextStyles.regular17)),
        AnimatedScale(
          scale: isPlaying ? 1.2 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: IconButton(
            tooltip: 'Прослушать $label',
            onPressed: onPlay,
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ),
      ],
    ),
  );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 21,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Рамка на выборе коротко «щёлкает»: без неё отклик читается
          // только по заливке, которая появляется позже.
          Container(
                decoration: SquircleBorders.squircleBorder(
                  color: UIColors.transparent,
                  borderRadius: 8,
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              )
              .animate(target: selected ? 1 : 0)
              .scaleXY(end: 1.12, duration: 110.ms, curve: Curves.easeOutBack)
              .then()
              .scaleXY(end: 1 / 1.12, duration: 170.ms, curve: Curves.easeOut),
          SizedBox.square(
                dimension: 13,
                child: Container(
                  decoration: SquircleBorders.squircleBorder(
                    color: accent,
                    borderRadius: 5,
                  ),
                ),
              )
              .animate(target: selected ? 1 : 0)
              .fadeIn(duration: 120.ms)
              .scaleXY(begin: .3, duration: 260.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}
