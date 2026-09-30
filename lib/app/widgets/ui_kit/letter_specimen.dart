import 'package:arabic_tajweed_app/app/widgets/ui_kit/orbital_rings_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/audio_track.dart';
import '../../resources/ui_resources.dart';
import '../margin.dart';
import 'play_control.dart';

/// Учебный образец для LetterWidgetCard: название, глиф на строках и звук.
/// Направляющая под буквой заполняется по настоящей позиции записи.
class LetterSpecimen extends StatelessWidget {
  const LetterSpecimen({
    required this.letter,
    this.title,
    this.badge,
    this.caption,
    this.onPlay,
    this.onAutoPlay,
    this.autoPlay = false,
    this.track,
    super.key,
  });

  final String letter;
  final String? title;
  final String? badge;
  final String? caption;
  final VoidCallback? onPlay;
  final VoidCallback? onAutoPlay;
  final bool autoPlay;
  final ValueListenable<AudioTrack>? track;

  static const _shapeSize = 320.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: UIColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: UIColors.borders, width: 1),
        boxShadow: [
          BoxShadow(
            color: UIColors.shadows,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null) ...[
                      Text(
                        badge!.toUpperCase(),
                        style: UITextStyles.monoSemibold11.copyWith(
                          color: UIColors.studyAccent,
                        ),
                      ),
                      const Margin.vertical(12),
                    ],
                    if (title != null)
                      Semantics(
                        header: true,
                        child: Text(title!, style: UITextStyles.semibold29),
                      ),
                  ],
                );
                final glyph = TweenAnimationBuilder<double>(
                  key: ValueKey(letter),
                  tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: reduceMotion ? 0 : 480),
                  curve: const Cubic(.16, .8, .24, 1),
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, (1 - value) * 12),
                    child: Opacity(opacity: .4 + .6 * value, child: child),
                  ),
                  child: _withTrack(
                    (audio) => LetterSpecimenGlyph(
                      letter: letter,
                      audio: audio,
                      showRings: true,
                    ),
                  ),
                );
                // Черты соединения (ـ) удлиняют рисунок одной буквы, но не
                // делают его словом: «ــتــ» остаётся компактным образцом.
                // Реальную ширину глифа подгоняет FittedBox выше.
                final glyphLength = letter
                    .replaceAll('\u0640', '')
                    .runes
                    .length;
                final stacked =
                    title == null ||
                    constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(16) > 21 ||
                    glyphLength > 4;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [heading, const Margin.vertical(8), glyph],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: heading),
                    const Margin.horizontal(16),
                    Expanded(flex: 2, child: glyph),
                  ],
                );
              },
            ),
            if (caption != null) ...[
              const Margin.vertical(8),
              Text(
                caption!,
                textAlign: TextAlign.center,
                style: UITextStyles.regular15,
              ),
            ],
            if (onPlay != null) ...[
              const Margin.vertical(16),
              Align(
                alignment: Alignment.centerLeft,
                child: PlayControl(
                  letter: letter,
                  onTap: onPlay!,
                  onAutoPlay: onAutoPlay,
                  autoPlay: autoPlay,
                  track: track,
                  label: 'Слушать',
                  size: 48,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _withTrack(Widget Function(AudioTrack) builder) {
    final listenable = track;
    if (listenable == null) return builder(AudioTrack.silent);
    return ValueListenableBuilder<AudioTrack>(
      valueListenable: listenable,
      builder: (_, audio, _) => builder(audio),
    );
  }
}

/// Белый образец буквы между направляющими для конспекта и результата задания.
class LetterSpecimenGlyph extends StatelessWidget {
  const LetterSpecimenGlyph({
    required this.letter,
    this.height = 128,
    this.fontSize = 96,
    this.audio = AudioTrack.silent,
    this.showRings = false,
    super.key,
  });

  final String letter;
  final double height;
  final double fontSize;
  final AudioTrack audio;
  final bool showRings;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _WritingGuides(
      rule: UIColors.ornamentStroke,
      accent: UIColors.primary,
      progress: audio.progress,
      playing: audio.isPlaying,
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        if (showRings)
          Positioned.fill(
            child: OverflowBox(
              minHeight: LetterSpecimen._shapeSize,
              maxHeight: LetterSpecimen._shapeSize,
              minWidth: LetterSpecimen._shapeSize,
              maxWidth: LetterSpecimen._shapeSize,
              child: OrbitalRingsWidget(
                color: UIColors.backgroundShapes2,
                thickness: 1.1,
                dashThickness: 1.5,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  letter,
                  textDirection: TextDirection.rtl,
                  style: UITextStyles.arabicRegular(fontSize, height: 1.25),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WritingGuides extends CustomPainter {
  const _WritingGuides({
    required this.rule,
    required this.accent,
    required this.progress,
    required this.playing,
  });

  final Color rule;
  final Color accent;
  final double progress;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = rule
      ..strokeWidth = .7;
    final baseline = size.height * .77;
    for (final y in [size.height * .2, baseline]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
      canvas.drawLine(Offset(0, y - 4), Offset(0, y + 4), pen);
      canvas.drawLine(
        Offset(size.width, y - 4),
        Offset(size.width, y + 4),
        pen,
      );
    }
    if (!playing && progress <= 0) return;
    // Направление воспроизведения привычное для плеера: слева направо.
    final end = size.width * progress.clamp(0, 1);
    pen
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, baseline), Offset(end, baseline), pen);
    if (playing) canvas.drawCircle(Offset(end, baseline), 3, pen);
  }

  @override
  bool shouldRepaint(_WritingGuides oldDelegate) =>
      oldDelegate.rule != rule ||
      oldDelegate.accent != accent ||
      oldDelegate.progress != progress ||
      oldDelegate.playing != playing;
}
