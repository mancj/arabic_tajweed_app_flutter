import 'dart:async';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Кнопка звучания: на ходу показывает остановку, в остальное время —
/// воспроизведение. Слушает запись сама, чтобы карточка не перестраивалась
/// на каждый кадр волны.
///
/// Она же заводит автоматическое звучание: буква звучит при появлении
/// карточки и при каждой смене глифа — состояние нужно только для этого.
class PlayControl extends StatefulWidget {
  const PlayControl({
    required this.letter,
    required this.onTap,
    required this.autoPlay,
    this.onAutoPlay,
    this.track,
    this.size = 46,
    this.showHint = true,
    super.key,
  });

  final String letter;
  final VoidCallback onTap;
  final VoidCallback? onAutoPlay;
  final ValueListenable<AudioTrack>? track;
  final bool autoPlay;
  final double size;
  final bool showHint;

  @override
  State<PlayControl> createState() => _PlayControlState();
}

class _PlayControlState extends State<PlayControl> {
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
  void didUpdateWidget(covariant PlayControl oldWidget) {
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
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        button: true,
        label: isPlaying ? 'Остановить' : 'Воспроизвести',
        child: CircleButton(
          size: widget.size,
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
      ),
      if (widget.showHint) ...[
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
    ],
  );
}
