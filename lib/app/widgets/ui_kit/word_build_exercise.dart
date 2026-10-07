import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/word_build_question.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'connected_word_preview.dart';
import 'exercise_choice_row.dart';
import 'letter_widget.dart';
import 'rule_card.dart';

class WordBuildExercise extends StatelessWidget {
  const WordBuildExercise({
    required this.question,
    required this.phase,
    required this.activeIndex,
    required this.formIds,
    required this.markIds,
    required this.evaluation,
    required this.animatedIndex,
    required this.onFormSelected,
    required this.onMarkSelected,
    required this.onPlay,
    required this.onAutoPlay,
    required this.track,
    this.autoPlay = true,
    this.showFeedback = true,
    super.key,
  });

  final WordBuildQuestion question;
  final WordBuildPhase phase;
  final int activeIndex;
  final List<String?> formIds;
  final List<String?> markIds;
  final WordBuildEvaluation? evaluation;
  final int? animatedIndex;
  final ValueChanged<String> onFormSelected;
  final ValueChanged<String> onMarkSelected;
  final VoidCallback onPlay;
  final VoidCallback onAutoPlay;
  final ValueListenable<AudioTrack> track;
  final bool autoPlay;
  final bool showFeedback;

  @override
  Widget build(BuildContext context) {
    final step = question.steps[activeIndex];
    final result = evaluation;
    final choosingForms = phase == WordBuildPhase.forms;
    final missingForms = formIds.where((id) => id == null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          letter: question.display,
          labelText: result != null
              ? result.correct
                    ? 'Слово собрано'
                    : 'Проверка слова'
              : '${choosingForms ? 'Формы букв' : 'Огласовки'} · ${activeIndex + 1} из ${question.steps.length}',
          question: 'Соберите слово по шагам',
          glyph: ConnectedWordPreview(
            glyphs: question.preview(formIds, markIds),
            activeIndex: activeIndex,
            accent: UIColors.primary,
            colors: result?.letters
                .map(
                  (letter) =>
                      letter.correct ? UIColors.success : UIColors.error,
                )
                .toList(),
            gapLabel:
                'Не заполнено букв: $missingForms. Всего букв: ${question.steps.length}',
            textKey: const ValueKey('word-build-preview'),
            gapKeyFor: (index) => ValueKey('word-build-gap-$index'),
            animatedIndex: animatedIndex,
          ),
          isArabic: true,
          onPlay: onPlay,
          onAutoPlay: onAutoPlay,
          track: track,
          autoPlay: autoPlay,
        ),
        const Margin.vertical(24),
        if (result == null) ...[
          Text(
            choosingForms
                ? 'Выберите форму буквы «${step.letter.label}»'
                : 'Огласовка буквы «${step.letter.label}» по звуку',
            style: UITextStyles.semibold17,
          ),
          const Margin.vertical(12),
          ExerciseChoiceRow(
            key: ValueKey('word-build-options-$phase-$activeIndex'),
            options: choosingForms ? step.formOptions : HarakaSyllables.marks,
            idFor: (atom) => atom.id,
            glyphFor: (atom) => atom.display,
            labelFor: (atom) => atom.label,
            keyPrefix: choosingForms ? 'word-build-form' : 'word-build-mark',
            selectedId: choosingForms
                ? formIds[activeIndex]
                : markIds[activeIndex],
            expectedId: choosingForms
                ? step.expectedFormId
                : step.expectedMarkId,
            checked: false,
            onSelected: choosingForms ? onFormSelected : onMarkSelected,
          ),
        ] else if (showFeedback)
          RuleCard(
            badge: result.correct ? 'Верно' : 'Попробуйте ещё раз',
            badgeColor: result.correct ? UIColors.success : UIColors.error,
            title: result.correct
                ? 'Слово собрано правильно'
                : result.formMistakes > 0 && result.markMistakes > 0
                ? 'Проверьте формы и огласовки'
                : result.formMistakes > 0
                ? 'Проверьте формы букв'
                : 'Проверьте огласовки',
            text: result.correct
                ? 'Послушайте и прочитайте собранное слово.'
                : '${_mistakes(result)}\n\nПри повторе верные формы и огласовки останутся.',
            child: result.correct
                ? null
                : Text(
                    question.display,
                    textDirection: TextDirection.rtl,
                    style: UITextStyles.arabicRegular48Compact,
                  ),
          ),
      ],
    );
  }

  String _mistakes(WordBuildEvaluation result) => [
    for (final (index, letter) in result.letters.indexed)
      if (!letter.correct)
        'Буква ${index + 1} (${question.steps[index].letter.label}): ${[if (!letter.formCorrect) 'форма', if (!letter.harakaCorrect) 'огласовка'].join(' и ')}.',
  ].join('\n');
}
