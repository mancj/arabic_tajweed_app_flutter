import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_check.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'letter_widget.dart';
import 'mono_text_button.dart';
import 'rule_card.dart';

/// Первая встреча даёт образец; при повторении он раскрывается по просьбе.
class PronunciationExercise extends StatefulWidget {
  const PronunciationExercise({
    required this.glyph,
    this.result,
    this.prompt = 'Прочитайте этот слог вслух',
    this.error,
    this.showFeedback = true,
    this.showRawHeard = false,
    this.showExampleInitially = false,
    this.autoPlayExample = false,
    this.exampleEnabled = true,
    this.onPlayExample,
    this.onAutoPlayExample,
    this.onPresented,
    this.track,
    super.key,
  });

  final String glyph;
  final String prompt;
  final PronunciationCheck? result;
  final String? error;
  final bool showFeedback;
  final bool showRawHeard;
  final bool showExampleInitially;
  final bool autoPlayExample;
  final bool exampleEnabled;
  final VoidCallback? onPlayExample;
  final VoidCallback? onAutoPlayExample;
  final VoidCallback? onPresented;
  final ValueListenable<AudioTrack>? track;

  @override
  State<PronunciationExercise> createState() => _PronunciationExerciseState();
}

class _PronunciationExerciseState extends State<PronunciationExercise> {
  late bool _exampleRevealed = widget.showExampleInitially;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPresented?.call();
    });
  }

  @override
  void didUpdateWidget(PronunciationExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glyph != widget.glyph) {
      _exampleRevealed = widget.showExampleInitially;
    }
  }

  void _revealExample() {
    if (!widget.exampleEnabled) return;
    setState(() => _exampleRevealed = true);
    widget.onPlayExample?.call();
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.result;
    final heard = widget.showRawHeard
        ? check?.rawHeard ?? check?.heard
        : check?.heard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          letter: widget.glyph,
          isArabic: true,
          labelText: 'Произношение',
          question: widget.showExampleInitially
              ? 'Послушайте и повторите'
              : widget.prompt,
          showPlay: _exampleRevealed,
          onPlay: widget.onPlayExample,
          onAutoPlay: widget.onAutoPlayExample,
          autoPlay: widget.autoPlayExample,
          playEnabled: widget.exampleEnabled,
          track: widget.track,
        ),
        if (!_exampleRevealed && widget.onPlayExample != null) ...[
          const Margin.vertical(8),
          Center(
            child: MonoTextButton(
              title: 'Послушать пример',
              icon: Icons.volume_up_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              onPressed: widget.exampleEnabled ? _revealExample : null,
            ),
          ),
        ],
        if (widget.error != null) ...[
          const Margin.vertical(24),
          RuleCard(badge: 'Проверка недоступна', title: widget.error!),
        ] else if (widget.showFeedback && check != null) ...[
          const Margin.vertical(24),
          RuleCard(
            badge: switch (check.status) {
              PronunciationStatus.matched => 'Верно',
              PronunciationStatus.mismatch => 'Попробуйте ещё раз',
              PronunciationStatus.unclear => 'Повторите запись',
            },
            title: check.feedbackTitle,
            text: check.hint,
            badgeColor: switch (check.status) {
              PronunciationStatus.matched => UIColors.success,
              PronunciationStatus.mismatch => UIColors.error,
              PronunciationStatus.unclear => UIColors.secondary2,
            },
            child: widget.showRawHeard
                ? Column(
                    children: [
                      Text('Сервер услышал', style: UITextStyles.regular15),
                      const Margin.vertical(8),
                      if (heard != null && heard.trim().isNotEmpty)
                        Text(
                          heard,
                          textDirection: TextDirection.rtl,
                          style: UITextStyles.arabicRegular48Compact,
                        )
                      else
                        Text(
                          'Нет распознанного текста',
                          style: UITextStyles.regular15,
                        ),
                    ],
                  )
                : check.canEvaluate && heard != null
                ? Text(
                    heard,
                    textDirection: TextDirection.rtl,
                    style: UITextStyles.arabicRegular48Compact,
                  )
                : null,
          ),
        ],
      ],
    );
  }
}
