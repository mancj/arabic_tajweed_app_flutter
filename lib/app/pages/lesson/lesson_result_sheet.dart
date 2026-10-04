import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:arabic_tajweed_app/app/media/single_sound_effect.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_specimen.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

import 'lesson_controller.dart';
import 'lesson_exercise_presentation.dart';

class LessonResultSheet extends StatefulWidget {
  const LessonResultSheet({required this.controller, super.key});

  final LessonController controller;

  @override
  State<LessonResultSheet> createState() => _LessonResultSheetState();
}

class _LessonResultSheetState extends State<LessonResultSheet>
    with SingleTickerProviderStateMixin {
  static const _autoAdvanceDuration = kDebugMode
      ? Duration(seconds: 3)
      : Duration(seconds: 3);

  late final SingleSoundEffect _answerSound;
  AnimationController? _autoAdvanceController;
  bool _advancing = false;

  LessonController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _answerSound = SingleSoundEffect(
      assetPath: controller.wasCorrect.value
          ? 'audio/correct_answer.m4a'
          : 'audio/incorrect.m4a',
    );
    unawaited(_answerSound.play());
    if (controller.wasCorrect.value) {
      _autoAdvanceController = AnimationController(
        vsync: this,
        duration: _autoAdvanceDuration,
      )..addStatusListener(_handleAutoAdvanceStatus);
      _autoAdvanceController!.forward();
    }
  }

  void _handleAutoAdvanceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _advance();
  }

  void _advance() {
    if (_advancing || !mounted) return;
    setState(() => _advancing = true);
    _autoAdvanceController?.stop();
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _autoAdvanceController?.dispose();
    unawaited(_answerSound.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = controller.wasCorrect.value;
    final exercise = controller.current;
    final label = exercise?.atom.label ?? 'ответ';
    final presentation = exercise == null
        ? null
        : LessonExercisePresentation.from(exercise);
    final isFormSequence = presentation?.input == LessonInputKind.formSequence;
    final check = controller.pronunciation.result.value;

    final title =
        presentation?.feedbackTitle(
          correct: correct,
          syllableBuildEvaluation: controller.syllableBuildEvaluation.value,
          syllableCheck: controller.pronunciation.syllableResult.value,
        ) ??
        (correct ? 'Верно!' : 'Попробуйте ещё раз');
    final text = presentation?.feedbackText(
      correct: correct,
      answerLabel: label,
      heard: check?.heard,
      syllableCheck: controller.pronunciation.syllableResult.value,
      formSequenceCorrectCount: controller.formSequenceCorrectCount,
      revealFormSequenceAnswer: controller.revealFormSequenceAnswer,
    );

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        decoration: BoxDecoration(
          color: UIColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: UIColors.secondary1,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Margin.vertical(24),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: correct
                          ? UIColors.primary
                          : UIColors.backgroundShapes1,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      correct ? Icons.check_rounded : Icons.refresh_rounded,
                      size: 16,
                      color: correct ? UIColors.white : UIColors.secondary1,
                    ),
                  ),
                  const Margin.horizontal(8),
                  Expanded(child: Text(title, style: UITextStyles.semibold22)),
                ],
              ),
              if (exercise != null && !isFormSequence) ...[
                const Margin.vertical(24),
                _ResultAnswerCard(atom: exercise.answer),
              ],
              if (text != null) ...[
                const Margin.vertical(16),
                Text(
                  text,
                  style: UITextStyles.regular17.copyWith(
                    color: UIColors.secondary2,
                  ),
                ),
              ],
              if (correct) ...[
                const Margin.vertical(16),
                AnimatedBuilder(
                  animation: _autoAdvanceController!,
                  builder: (context, _) {
                    final progress = _autoAdvanceController!.value;
                    final secondsLeft =
                        (_autoAdvanceDuration.inSeconds * (1 - progress))
                            .ceil();
                    return Semantics(
                      label: 'Автоматический переход',
                      value: 'Через $secondsLeft секунд',
                      child: Column(
                        key: const ValueKey('correct-answer-auto-progress'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Продолжение через $secondsLeft сек.',
                            style: UITextStyles.regular12.copyWith(
                              color: UIColors.secondary1,
                            ),
                          ),
                          const Margin.vertical(8),
                          ExcludeSemantics(
                            child: LessonProgressBar(
                              value: progress,
                              wavy: true,
                              animateOnChange: false,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const Margin.vertical(24),
              NextButton(
                title: correct ? 'Продолжить' : 'Попробовать ещё раз',
                enabled: !_advancing,
                onTap: _advance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultAnswerCard extends StatelessWidget {
  const _ResultAnswerCard({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    final hasGlyph = LessonAtomPresentation(atom).hasGlyph;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UIColors.highlightArea,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: UIColors.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasGlyph) ...[
            Semantics(
              label: 'Буква ${atom.display}',
              child: ExcludeSemantics(
                child: LetterSpecimenGlyph(
                  letter: atom.display,
                  height: 112,
                  fontSize: 88,
                ),
              ),
            ),
            const Margin.vertical(16),
          ],
          Text(
            'ПРАВИЛЬНЫЙ ОТВЕТ',
            style: UITextStyles.monoSemibold11.copyWith(
              color: UIColors.secondary1,
            ),
          ),
          const Margin.vertical(8),
          Text(
            atom.label.isNotEmpty ? atom.label : atom.display,
            style: UITextStyles.semibold22,
          ),
        ],
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return card;
    return card
        .animate()
        .fadeIn(duration: .28.seconds)
        .moveY(
          begin: 12,
          end: 0,
          duration: .28.seconds,
          curve: Curves.easeOutCubic,
        );
  }
}
