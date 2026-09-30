import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/glow_wave_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Нижняя панель записи голоса: кнопку держат, пока говорят.
/// Во время проверки вместо кнопки показывается светящаяся волна.
/// Состояние приходит снаружи: панель ничего не знает о сервере.
class RecordBar extends StatelessWidget {
  final bool recording;
  final bool checking;

  /// Что написано над кнопкой в покое: «Удерживайте и назовите букву».
  final String idleHint;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  /// Слот под кнопкой — например «Пропустить задание», когда сервера нет.
  final Widget? footer;

  const RecordBar({
    required this.recording,
    required this.checking,
    required this.idleHint,
    this.onPressStart,
    this.onPressEnd,
    this.footer,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = switch ((recording, checking)) {
      (true, _) => 'Слушаю… отпустите, когда назовёте',
      (_, true) => 'Проверяю…',
      _ => idleHint,
    };

    return Column(
      key: ValueKey(status),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checking)
          GlowWaveWidget(
            height: 52,
            width: 300,
            amplitude: 24,
            glowIntensity: .2,
            glowSpread: 1,
            pairCount: 14,
            lineWidth: 1,
            color: UIColors.text,
          ).animate().fadeIn(duration: 200.milliseconds)
        else
          AnimatedScale(
                scale: recording ? 1.15 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: CircleButton(
                  size: 72,
                  onPressStart: checking ? null : onPressStart,
                  onPressEnd: onPressEnd,
                  child: GestureDetector(
                    onTapDown: (_) => onPressStart?.call(),
                    onTapUp: (_) => onPressEnd?.call(),
                    onTapCancel: onPressEnd,
                    child: Icon(
                      CupertinoIcons.mic_fill,
                      size: 30,
                      color: UIColors.primaryButtonText,
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 200.milliseconds)
              .scaleXY(begin: .8, curve: Curves.easeOutBack),
        const Margin.vertical(12),
        Builder(
          key: ValueKey(status),
          builder: (context) {
            return Text(
                  status,
                  style: UITextStyles.monoRegular12.copyWith(
                    color: UIColors.secondary2,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate(
                  onPlay: (controller) {
                    if (checking) controller.repeat();
                  },
                )
                .shimmer(duration: 1.seconds);
          },
        ),
        if (footer case final footer?) ...[const Margin.vertical(8), footer],
      ],
    );
  }
}
