import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/syllable_build_question.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'exercise_choice_row.dart';
import 'letter_widget.dart';
import 'rule_card.dart';

/// Образец скрыт до проверки; в карточке видна только собственная сборка.
class SyllableBuildExercise extends StatelessWidget {
  const SyllableBuildExercise({
    required this.question,
    required this.selectedLetterId,
    required this.selectedMarkId,
    required this.evaluation,
    required this.onLetterSelected,
    required this.onMarkSelected,
    required this.onPlay,
    required this.onAutoPlay,
    required this.track,
    this.showFeedback = true,
    this.autoPlay = true,
    super.key,
  });

  final SyllableBuildQuestion question;
  final String? selectedLetterId;
  final String? selectedMarkId;
  final SyllableBuildEvaluation? evaluation;
  final ValueChanged<String> onLetterSelected;
  final ValueChanged<String> onMarkSelected;
  final VoidCallback onPlay;
  final VoidCallback onAutoPlay;
  final ValueListenable<AudioTrack> track;
  final bool showFeedback;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    final preview = question.preview(selectedLetterId, selectedMarkId);
    final result = evaluation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          letter: question.prompt.id,
          glyph: preview == null
              ? Icon(Icons.hearing_rounded, size: 48, color: UIColors.primary)
              : Text(
                  preview,
                  key: const ValueKey('syllable-build-preview'),
                  textDirection: TextDirection.rtl,
                  style: UITextStyles.arabicRegular64Compact,
                ),
          isArabic: true,
          labelText: preview == null ? 'Послушайте' : 'Ваш слог',
          question: 'Соберите слог по звуку',
          onPlay: onPlay,
          onAutoPlay: onAutoPlay,
          autoPlay: autoPlay,
          track: track,
        ),
        const Margin.vertical(24),
        Text('1. Выберите букву', style: UITextStyles.semibold17),
        const Margin.vertical(12),
        ExerciseChoiceRow(
          options: question.letterOptions,
          idFor: (atom) => atom.letterId!,
          glyphFor: HarakaSyllables.bareGlyphFor,
          labelFor: (atom) => 'Буква ${HarakaSyllables.bareGlyphFor(atom)}',
          keyPrefix: 'syllable-build-letter',
          selectedId: selectedLetterId,
          expectedId: question.prompt.letterId!,
          checked: result != null,
          onSelected: onLetterSelected,
        ),
        if (selectedLetterId != null) ...[
          const Margin.vertical(24),
          Text('2. Добавьте огласовку', style: UITextStyles.semibold17),
          const Margin.vertical(12),
          ExerciseChoiceRow(
            options: HarakaSyllables.marks,
            idFor: (atom) => atom.id,
            glyphFor: (atom) => atom.display,
            labelFor: (atom) => atom.label,
            keyPrefix: 'syllable-build-mark',
            selectedId: selectedMarkId,
            expectedId: question.expectedMarkId,
            checked: result != null,
            onSelected: onMarkSelected,
          ),
        ],
        if (showFeedback && result != null) ...[
          const Margin.vertical(24),
          RuleCard(
            badge: result.correct ? 'Верно' : 'Разбор',
            badgeColor: result.correct ? UIColors.success : UIColors.error,
            title: switch ((result.letterCorrect, result.harakaCorrect)) {
              (true, true) => 'Слог собран правильно',
              (true, false) => 'Буква верная, огласовка отличается',
              (false, true) => 'Огласовка верная, буква отличается',
              (false, false) => 'Буква и огласовка отличаются',
            },
            text:
                'В записи звучит ${question.prompt.display}. '
                'Огласовка — ${HarakaSyllables.marks.firstWhere((mark) => mark.id == question.expectedMarkId).label.toLowerCase()}.',
            child: Text(
              question.prompt.display,
              textDirection: TextDirection.rtl,
              style: UITextStyles.arabicRegular48Compact,
            ),
          ),
        ],
      ],
    );
  }
}
