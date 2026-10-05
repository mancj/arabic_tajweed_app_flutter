import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'exercise_choice_row.dart';
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
          glyph: _ConnectionPreview(
            question: question,
            selectedFormId: selectedFormId,
            selectedMarkId: selectedMarkId,
            evaluation: result,
          ),
          isArabic: true,
          onPlay: onPlay,
          onAutoPlay: onAutoPlay,
          autoPlay: true,
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
        if (result != null) ...[
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

/// Части стоят на одной строке справа налево, без отдельных карточек.
/// ZWJ задаёт выбранную форму, ZWNJ между частями запрещает её автозамену.
class _ConnectionPreview extends StatelessWidget {
  const _ConnectionPreview({
    required this.question,
    required this.selectedFormId,
    required this.selectedMarkId,
    required this.evaluation,
  });

  final ConnectionBuildQuestion question;
  final String? selectedFormId;
  final String? selectedMarkId;
  final ConnectionBuildEvaluation? evaluation;

  @override
  Widget build(BuildContext context) {
    final glyphs = question.preview(selectedFormId, selectedMarkId);
    final color = evaluation == null
        ? UIColors.primary
        : evaluation!.correct
        ? UIColors.success
        : UIColors.error;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        key: const ValueKey('connection-build-preview'),
        TextSpan(
          children: [
            for (final (index, glyph) in glyphs.indexed) ...[
              if (index > 0) const TextSpan(text: '\u200c'),
              if (glyph != null)
                TextSpan(
                  text: glyph,
                  style: index == question.missingIndex
                      ? UITextStyles.arabicRegular64Compact.copyWith(
                          color: color,
                        )
                      : null,
                )
              else
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Semantics(
                    label: 'Недостающая буква ${question.position}',
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      key: const ValueKey('connection-build-gap'),
                      width: 56,
                      height: 64,
                      decoration: BoxDecoration(
                        color: UIColors.primary10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: UIColors.primary, width: 1.5),
                      ),
                      child: Icon(
                        Icons.question_mark_rounded,
                        color: UIColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: UITextStyles.arabicRegular64Compact,
      ),
    );
  }
}
