import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../../domain/audio_track.dart';
import 'tracing_card.dart';

/// Рисование огласовки относительно неподвижной буквы.
/// Жесты, проверка и подсказки остаются в общем [DrawingCanvas].
class HarakaDrawingCard extends StatelessWidget {
  const HarakaDrawingCard({
    required this.letter,
    required this.title,
    required this.hint,
    required this.onClear,
    required this.controller,
    required this.matcher,
    required this.mode,
    required this.shape,
    required this.enabled,
    required this.missesBeforeReveal,
    this.onPlay,
    this.onAutoPlay,
    this.track,
    this.playbackKey,
    this.autoPlay = true,
    this.onProgress,
    this.onChecked,
    this.onReveal,
    this.onMerged,
    super.key,
  });

  final String letter;
  final String title;
  final String hint;
  final VoidCallback onClear;
  final DrawingController controller;
  final TracingMatcher matcher;
  final TracingMode mode;
  final TracingShape? shape;
  final bool enabled;
  final int missesBeforeReveal;
  final VoidCallback? onPlay;
  final VoidCallback? onAutoPlay;
  final ValueListenable<AudioTrack>? track;
  final String? playbackKey;
  final bool autoPlay;
  final ValueChanged<TracingProgress>? onProgress;
  final ValueChanged<TracingMatchResult>? onChecked;
  final VoidCallback? onReveal;
  final VoidCallback? onMerged;

  @override
  Widget build(BuildContext context) {
    return TracingCard(
      badge: 'Задание',
      title: title,
      hint: hint,
      onClear: onClear,
      onPlay: onPlay,
      onAutoPlay: onAutoPlay,
      track: track,
      playbackKey: playbackKey,
      autoPlay: autoPlay,
      controller: controller,
      matcher: matcher,
      mode: mode,
      placement: TracingPlacement.anchored,
      shape: shape,
      canvasBackground: Transform.translate(
        offset: const Offset(0, 18),
        child: Text(
          letter,
          textDirection: TextDirection.rtl,
          style: UITextStyles.arabicRegular(
            144,
            height: 1,
          ).copyWith(color: UIColors.secondary2.withValues(alpha: .42)),
        ),
      ),
      enabled: enabled,
      missesBeforeReveal: missesBeforeReveal,
      onProgress: onProgress,
      onChecked: onChecked,
      onReveal: onReveal,
      onMerged: onMerged,
    );
  }
}
