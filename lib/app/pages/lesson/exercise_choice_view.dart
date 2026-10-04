import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/audio_track.dart';
import '../../../domain/atom.dart';
import '../../../domain/exercise.dart';
import '../../../domain/progress_event.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/ui_kit/answer_option.dart';
import '../../widgets/ui_kit/letter_widget.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/question_card.dart';
import 'lesson_exercise_presentation.dart';

/// Общие карточка и вариант выбора для урока и проверки знаний.
class ExerciseChoiceQuestion extends StatelessWidget {
  const ExerciseChoiceQuestion({
    required this.exercise,
    required this.presentation,
    required this.cardKey,
    this.nameRevealed = false,
    this.onRevealName,
    this.onPlay,
    this.onAutoPlay,
    this.autoPlay = false,
    this.track,
    super.key,
  });

  final Exercise exercise;
  final LessonExercisePresentation presentation;
  final Key cardKey;
  final bool nameRevealed;
  final VoidCallback? onRevealName;
  final VoidCallback? onPlay;
  final VoidCallback? onAutoPlay;
  final bool autoPlay;
  final ValueListenable<AudioTrack>? track;

  @override
  Widget build(BuildContext context) {
    final atom = exercise.atom;
    if (presentation.question == LessonQuestionKind.audio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LetterWidgetCard(
            key: cardKey,
            letter: '?',
            glyph: SvgPicture.asset(
              UISVGAssets.questionMark,
              height: 48,
              colorFilter: ColorFilter.mode(UIColors.primary, BlendMode.srcIn),
            ),
            isArabic: false,
            labelText: 'Вопрос',
            question: presentation.prompt,
            subtitle: nameRevealed
                ? atom.kind == AtomKind.word
                      ? atom.display
                      : atom.label
                : null,
            onPlay: onPlay,
            onAutoPlay: onAutoPlay,
            autoPlay: autoPlay,
            track: track,
          ),
          if (!nameRevealed && onRevealName != null)
            MonoTextButton(
              title: presentation.audioHintAction,
              onPressed: onRevealName,
            ),
        ],
      );
    }
    if (presentation.question == LessonQuestionKind.label) {
      return QuestionCard(
        badge: 'Вопрос',
        question: presentation.prompt,
        subject: atom.label,
        subjectFont: UITextStyles.fontOnest,
      );
    }
    return LetterWidgetCard(
      key: cardKey,
      letter: atom.display,
      labelText: 'Вопрос',
      question: presentation.prompt,
      showPlay: false,
      isArabic: true,
    );
  }
}

class ExerciseChoiceOption extends StatelessWidget {
  const ExerciseChoiceOption({
    required this.exercise,
    required this.presentation,
    required this.option,
    required this.index,
    required this.selected,
    required this.revealed,
    required this.onTap,
    this.onPlay,
    this.playbackProgress = 0,
    this.isPlaying = false,
    super.key,
  });

  final Exercise exercise;
  final LessonExercisePresentation presentation;
  final Atom option;
  final int index;
  final bool selected;
  final bool revealed;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final double playbackProgress;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final isAnswer = index == exercise.answerIndex;
    final color = switch ((revealed, isAnswer, selected)) {
      (true, true, _) => UIColors.primary,
      (true, false, true) => UIColors.secondary1,
      _ => UIColors.primary,
    };
    if (exercise.mode == ExerciseMode.letterToSound) {
      return AudioAnswerOption(
        label: 'Звучание ${index + 1}',
        selected: selected || (revealed && isAnswer),
        accent: color,
        playbackProgress: playbackProgress,
        isPlaying: isPlaying,
        onTap: onTap ?? () {},
        onPlay: onPlay ?? () {},
      );
    }
    return AnswerOption(
      selected: selected || (revealed && isAnswer),
      accent: color,
      playbackProgress: playbackProgress,
      onTap: onTap,
      child: presentation.optionsAreGlyphs
          ? Text(
              option.display,
              style: UITextStyles.arabicRegular(28),
              textDirection: TextDirection.rtl,
            )
          : Text(option.label, style: UITextStyles.regular17),
    );
  }
}
