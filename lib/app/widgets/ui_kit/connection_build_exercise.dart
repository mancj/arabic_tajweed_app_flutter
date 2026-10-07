import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'exercise_choice_row.dart';
import 'connected_word_preview.dart';
import 'letter_widget.dart';
import 'rule_card.dart';

class ConnectionBuildExercise extends StatelessWidget {
  const ConnectionBuildExercise({
    required this.question,
    required this.selectedFormId,
    required this.selectedMarkId,
    required this.evaluation,
    required this.onFormSelected,
    required this.onMarkSelected,
    required this.onPlay,
    required this.onAutoPlay,
    required this.track,
    this.autoPlay = true,
    this.showFeedback = true,
    super.key,
  });

  final ConnectionBuildQuestion question;
  final String? selectedFormId;
  final String? selectedMarkId;
  final ConnectionBuildEvaluation? evaluation;
  final ValueChanged<String> onFormSelected;
  final ValueChanged<String> onMarkSelected;
  final VoidCallback onPlay;
  final VoidCallback onAutoPlay;
  final ValueListenable<AudioTrack> track;
  final bool autoPlay;
  final bool showFeedback;

  @override
  Widget build(BuildContext context) {
    final result = evaluation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          letter: '${question.display}-${question.missingIndex}',
          labelText: question.parts.length == 2
              ? 'Короткая связка'
              : 'Короткое слово',
          question: 'Достройте соединение',
          glyph: ConnectedWordPreview(
            glyphs: question.preview(selectedFormId, selectedMarkId),
            activeIndex: question.missingIndex,
            accent: result == null
                ? UIColors.primary
                : result.correct
                ? UIColors.success
                : UIColors.error,
            gapLabel: 'Недостающая буква ${question.position}',
            textKey: const ValueKey('connection-build-preview'),
          ),
          isArabic: true,
          onPlay: onPlay,
          onAutoPlay: onAutoPlay,
          autoPlay: autoPlay,
          track: track,
        ),
        const Margin.vertical(24),
        Text(
          '1. Выберите форму ${question.position}',
          style: UITextStyles.semibold17,
        ),
        const Margin.vertical(12),
        ExerciseChoiceRow(
          options: question.formOptions,
          idFor: (atom) => atom.id,
          glyphFor: (atom) => atom.display,
          labelFor: (atom) => atom.label,
          keyPrefix: 'connection-build-form',
          selectedId: selectedFormId,
          expectedId: question.expectedFormId,
          checked: result != null,
          onSelected: onFormSelected,
        ),
        if (selectedFormId != null) ...[
          const Margin.vertical(24),
          Text(
            '2. Добавьте огласовку по звуку',
            style: UITextStyles.semibold17,
          ),
          const Margin.vertical(12),
          ExerciseChoiceRow(
            options: HarakaSyllables.marks,
            idFor: (atom) => atom.id,
            glyphFor: (atom) => atom.display,
            labelFor: (atom) => atom.label,
            keyPrefix: 'connection-build-mark',
            selectedId: selectedMarkId,
            expectedId: question.expectedMarkId,
            checked: result != null,
            onSelected: onMarkSelected,
          ),
        ],
        if (result != null && showFeedback) ...[
          const Margin.vertical(24),
          RuleCard(
            badge: result.correct ? 'Верно' : 'Попробуйте ещё раз',
            badgeColor: result.correct ? UIColors.success : UIColors.error,
            title: switch ((result.formCorrect, result.harakaCorrect)) {
              (true, true) => 'Соединение собрано правильно',
              (true, false) => 'Форма верная, огласовка отличается',
              (false, true) => 'Огласовка верная, форма отличается',
              (false, false) => 'Форма и огласовка отличаются',
            },
            text: result.correct
                ? 'Послушайте и прочитайте собранное соединение.'
                : 'Правильная запись показана ниже. При повторе верная часть останется.',
            child: Text(
              question.display,
              textDirection: TextDirection.rtl,
              style: UITextStyles.arabicRegular48Compact,
            ),
          ),
        ],
      ],
    );
  }
}
