import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';

/// Объясняет три краткие огласовки на разных буквах и заканчивается
/// общей таблицей для сравнения.
class HarakaExamplesOverview extends StatefulWidget {
  const HarakaExamplesOverview({
    required this.fathaExamples,
    required this.kasraExamples,
    required this.dammaExamples,
    required this.summaryExamples,
    required this.onPlay,
    required this.track,
    super.key,
  });

  final List<Atom> fathaExamples;
  final List<Atom> kasraExamples;
  final List<Atom> dammaExamples;
  final List<Atom> summaryExamples;
  final ValueChanged<Atom> onPlay;
  final ValueListenable<AudioTrack> track;

  @override
  State<HarakaExamplesOverview> createState() => _HarakaExamplesOverviewState();
}

class _HarakaExamplesOverviewState extends State<HarakaExamplesOverview> {
  String? _activeId;

  void _play(Atom atom) {
    setState(() => _activeId = atom.id);
    widget.onPlay(atom);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioTrack>(
      valueListenable: widget.track,
      builder: (context, track, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HarakaSection(
            title: 'Фатха  َ',
            text: 'Ставится над буквой и даёт краткий звук «а».',
            examples: widget.fathaExamples,
            activeId: _activeId,
            isPlaying: track.isPlaying,
            onPlay: _play,
          ),
          const Margin.vertical(24),
          _HarakaSection(
            title: 'Касра  ِ',
            text: 'Ставится под буквой и даёт краткий звук «и».',
            examples: widget.kasraExamples,
            activeId: _activeId,
            isPlaying: track.isPlaying,
            onPlay: _play,
          ),
          const Margin.vertical(24),
          _HarakaSection(
            title: 'Дамма  ُ',
            text: 'Ставится над буквой и даёт краткий звук «у».',
            examples: widget.dammaExamples,
            activeId: _activeId,
            isPlaying: track.isPlaying,
            onPlay: _play,
          ),
          const Margin.vertical(32),
          Text('Все вместе', style: UITextStyles.semibold17),
          const Margin.vertical(8),
          Text(
            'Одна и та же буква звучит по-разному в зависимости от знака. '
            'Нажмите на примеры и сравните.',
            style: UITextStyles.regular15,
          ),
          const Margin.vertical(16),
          HarakaExamplesGrid(
            examples: widget.summaryExamples,
            activeId: _activeId,
            isPlaying: track.isPlaying,
            onPlay: _play,
          ),
        ],
      ),
    );
  }
}

class _HarakaSection extends StatelessWidget {
  const _HarakaSection({
    required this.title,
    required this.text,
    required this.examples,
    required this.activeId,
    required this.isPlaying,
    required this.onPlay,
  });

  final String title;
  final String text;
  final List<Atom> examples;
  final String? activeId;
  final bool isPlaying;
  final ValueChanged<Atom> onPlay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: UITextStyles.semibold17),
      const Margin.vertical(8),
      Text(text, style: UITextStyles.regular15),
      const Margin.vertical(16),
      HarakaExamplesGrid(
        examples: examples,
        activeId: activeId,
        isPlaying: isPlaying,
        onPlay: onPlay,
      ),
    ],
  );
}

/// Компактная сетка озвученных примеров.
class HarakaExamplesGrid extends StatelessWidget {
  const HarakaExamplesGrid({
    required this.examples,
    required this.activeId,
    required this.isPlaying,
    required this.onPlay,
    super.key,
  });

  final List<Atom> examples;
  final String? activeId;
  final bool isPlaying;
  final ValueChanged<Atom> onPlay;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.25,
    ),
    itemCount: examples.length,
    itemBuilder: (context, index) {
      final example = examples[index];
      final exampleIsPlaying = isPlaying && activeId == example.id;
      return Semantics(
        button: true,
        label:
            '${exampleIsPlaying ? 'Остановить' : 'Воспроизвести'} ${example.display}',
        child: AppGestureDetector(
          onTap: () => onPlay(example),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: SquircleBorders.squircleBorder(
              color: exampleIsPlaying
                  ? UIColors.primary10
                  : UIColors.highlightArea,
              borderRadius: 16,
              cornerSmoothing: .8,
              borderSide: BorderSide(
                color: exampleIsPlaying ? UIColors.primary : UIColors.borders,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    example.display,
                    textDirection: TextDirection.rtl,
                    style: UITextStyles.arabicRegular38Compact,
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Icon(
                    exampleIsPlaying
                        ? Icons.stop_rounded
                        : Icons.volume_up_rounded,
                    size: 16,
                    color: exampleIsPlaying
                        ? UIColors.primary
                        : UIColors.secondary1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
