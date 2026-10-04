import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../widgets/drawing/haraka_shape_layout.dart';
import '../../widgets/drawing/tracing_shape_svg.dart';
import '../../../domain/audio_track.dart';
import 'tracing_card.dart';

/// Рисование огласовки относительно неподвижной буквы.
/// Жесты, проверка и подсказки остаются в общем [DrawingCanvas].
class HarakaDrawingCard extends StatefulWidget {
  static const letterScale = .8;
  static const strokeWidth = 10.0;
  static const bandScale = 2.0;

  const HarakaDrawingCard({
    required this.letterId,
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

  final String letterId;
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
  State<HarakaDrawingCard> createState() => _HarakaDrawingCardState();
}

class _HarakaDrawingCardState extends State<HarakaDrawingCard> {
  TracingShape? _letterShape;
  TracingShape? _positionedSource;
  TracingShape? _positionedLetter;
  TracingShape? _positionedShape;

  @override
  void initState() {
    super.initState();
    _loadLetter();
  }

  @override
  void didUpdateWidget(HarakaDrawingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.letterId != oldWidget.letterId) {
      _letterShape = null;
      _clearPositionedShape();
      _loadLetter();
    }
  }

  Future<void> _loadLetter() async {
    final letterId = widget.letterId;
    try {
      final shape = await TracingShapeSvg.load(
        'assets/svg/alphabet/${letterId}_base.svg',
        id: '${letterId}_base',
      );
      if (mounted && widget.letterId == letterId) {
        setState(() {
          _letterShape = shape.transformed(
            HarakaDrawingCard.letterScale,
            shape.frame.center * (1 - HarakaDrawingCard.letterScale),
          );
          _clearPositionedShape();
        });
      }
    } catch (_) {
      // Без SVG буквы закреплённое положение огласовки определить нельзя.
    }
  }

  void _clearPositionedShape() {
    _positionedSource = null;
    _positionedLetter = null;
    _positionedShape = null;
  }

  TracingShape? _placeHaraka(TracingShape? source, TracingShape? letter) {
    if (source == null || letter == null) return null;
    if (source != _positionedSource || letter != _positionedLetter) {
      _positionedSource = source;
      _positionedLetter = letter;
      _positionedShape = HarakaShapeLayout.place(
        haraka: source,
        letter: letter,
      );
    }
    return _positionedShape;
  }

  @override
  Widget build(BuildContext context) {
    final letterShape = _letterShape;
    final shape = _placeHaraka(widget.shape, letterShape);
    return TracingCard(
      badge: 'Задание',
      title: widget.title,
      hint: widget.hint,
      onClear: widget.onClear,
      onPlay: widget.onPlay,
      onAutoPlay: widget.onAutoPlay,
      track: widget.track,
      playbackKey: widget.playbackKey,
      autoPlay: widget.autoPlay,
      controller: widget.controller,
      matcher: widget.matcher,
      allowHiddenGuideMatch: widget.shape?.id.split('/').last == 'damma',
      allowAnyPosition:
          widget.mode == TracingMode.freehand &&
          widget.shape?.id.split('/').last == 'damma',
      mode: widget.mode,
      placement: TracingPlacement.anchored,
      shape: shape,
      strokeWidth: HarakaDrawingCard.strokeWidth,
      bandScale: HarakaDrawingCard.bandScale,
      canvasBackground: letterShape == null
          ? null
          : SizedBox.expand(
              child: CustomPaint(
                painter: _ShapePainter(
                  shape: letterShape,
                  color: UIColors.secondary2.withValues(alpha: .42),
                ),
              ),
            ),
      enabled: widget.enabled && shape != null,
      missesBeforeReveal: widget.missesBeforeReveal,
      onProgress: widget.onProgress,
      onChecked: widget.onChecked,
      onReveal: widget.onReveal,
      onMerged: widget.onMerged,
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({required this.shape, required this.color});

  final TracingShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final resolved = shape.resolve(size, padding: 0);
    resolved.paint(canvas, color, strokeWidth: resolved.strokeWidth * .85);
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}
