import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/letter_audio.dart';
import '../../../data/lesson_audio.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/knowledge_check.dart';
import '../../../domain/lesson_pacing.dart';
import '../../../domain/progress_event.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/explanation_asset_card.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/rule_card.dart';
import '../lesson/lesson_audio_source.dart';
import '../lesson/lesson_exercise_presentation.dart';
import '../lesson/exercise_choice_view.dart';
import '../lesson/option_audio_sequence.dart';
import 'course_controller.dart';

class KnowledgeCheckPage extends StatefulWidget {
  const KnowledgeCheckPage({
    required this.controller,
    required this.topic,
    this.audio,
    super.key,
  });
  final CourseController controller;
  final Topic topic;
  final LessonAudio? audio;
  @override
  State<KnowledgeCheckPage> createState() => _KnowledgeCheckPageState();
}

class _KnowledgeCheckPageState extends State<KnowledgeCheckPage> {
  late final check = KnowledgeCheck(
    curriculum: widget.controller.curriculum,
    topic: widget.topic,
    context: widget.controller.context,
  );
  final _scroll = ScrollController();
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  late final OptionAudioSequence _optionAudio = OptionAudioSequence(
    audio: _audio,
  );
  final _audioSource = const LessonAudioSource();
  bool started = false;
  bool busy = false;
  bool finished = false;
  String? error;
  int index = 0;
  int conceptIndex = 0;
  int? selected;
  int? session;
  final correct = <String, int>{};
  final confirmed = <String>{};

  bool get passed =>
      check.knowledgeAtoms.every((atom) => confirmed.contains(atom.id));

  Future<void> _advance() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      session ??= await widget.controller.repository.nextSessionId();
      if (!started) {
        started = true;
      } else if (conceptIndex < check.concepts.length) {
        await widget.controller.repository.record(
          AtomIntroduced(
            atomId: check.concepts[conceptIndex].id,
            sessionId: session!,
            at: widget.controller.today,
          ),
        );
        conceptIndex++;
      } else if (index < check.questions.length && selected != null) {
        final q = check.questions[index];
        _optionAudio.cancel();
        await _audio.stop();
        final count =
            (correct[q.atom.id] ?? 0) + (selected == q.answerIndex ? 1 : 0);
        if (count == 2 && !confirmed.contains(q.atom.id)) {
          await widget.controller.repository.record(
            KnowledgeConfirmed(
              atomId: q.atom.id,
              sessionId: session!,
              at: widget.controller.today,
            ),
          );
          confirmed.add(q.atom.id);
        }
        correct[q.atom.id] = count;
        index++;
        selected = null;
      }
      if (started &&
          conceptIndex == check.concepts.length &&
          index == check.questions.length) {
        if (check.inferredAtoms.isNotEmpty &&
            check.checkedAtoms.every((atom) => correct[atom.id] == 2)) {
          for (final atom in check.inferredAtoms) {
            if (confirmed.contains(atom.id)) continue;
            await widget.controller.repository.record(
              KnowledgeConfirmed(
                atomId: atom.id,
                sessionId: session!,
                at: widget.controller.today,
              ),
            );
            confirmed.add(atom.id);
          }
        }
        if (passed) {
          var checkpointLetters = 0;
          final known = {
            ...confirmed,
            for (final entry in widget.controller.context.progress.entries)
              if (entry.value.state.index >= AtomState.known.index) entry.key,
          };
          final knownPrefix = widget.controller.curriculum.baseLetters
              .takeWhile((atom) => known.contains(atom.id))
              .length;
          for (final threshold
              in widget.controller.rules.alphabetCheckpointLetters) {
            if (threshold <= knownPrefix) checkpointLetters = threshold;
          }
          await widget.controller.repository.finishSession(
            sessionId: session!,
            purpose: LessonPurpose.placementCheck,
            exerciseCount: check.questions.length,
            firstTryCorrect: check.questions.length,
            checkpointLetters: checkpointLetters == 0
                ? null
                : checkpointLetters,
            at: widget.controller.today,
          );
        }
        await widget.controller.refreshBoard();
        finished = true;
      }
    } catch (_) {
      error = 'Не удалось сохранить ответ. Попробуйте ещё раз.';
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
        if (error == null) _startOptionAudioAfterFrame();
        if (error == null && _scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  void _startOptionAudioAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !started ||
          conceptIndex < check.concepts.length ||
          index >= check.questions.length) {
        return;
      }
      final question = check.questions[index];
      if (question.mode != ExerciseMode.letterToSound) return;
      unawaited(
        _optionAudio.playAll(
          question.options.map(_audioSource.forAtom).toList(growable: false),
        ),
      );
    });
  }

  @override
  void dispose() {
    _optionAudio.dispose();
    unawaited(_audio.dispose());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final concept = conceptIndex < check.concepts.length
        ? check.concepts[conceptIndex]
        : null;
    final question = index < check.questions.length
        ? check.questions[index]
        : null;
    final mode = question?.mode;
    final presentation = question == null
        ? null
        : LessonExercisePresentation.from(question);
    final target = widget.controller.statuses.firstWhere(
      (s) => s.topic.id == widget.topic.id,
    );
    return AppScaffold(
      title: 'Проверка знаний',
      bottomBar: NextButton(
        title: finished
            ? (passed ? 'Начать новую тему' : 'Вернуться к теме')
            : !started
            ? 'Начать проверку'
            : concept != null
            ? 'Понятно'
            : question == null
            ? 'Завершить проверку'
            : 'Ответить',
        enabled:
            !busy &&
            (finished ||
                !started ||
                concept != null ||
                question == null ||
                selected != null),
        onTap: finished
            ? () async {
                if (passed) {
                  await widget.controller.open(
                    target,
                    respectCourseGates: false,
                  );
                }
                if (context.mounted) Navigator.of(context).pop();
              }
            : _advance,
      ),
      builder: (context, insets) => ListView(
        controller: _scroll,
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          if (error != null) ...[
            Text(error!, style: UITextStyles.regular17),
            const Margin.vertical(12),
          ],
          if (finished) ...[
            RuleCard(
              title: passed ? 'Тема открыта' : 'Пока есть пробелы',
              text: passed
                  ? '«${widget.topic.title}» доступна. '
                        '${check.inferredAtoms.isNotEmpty ? 'Остальной пропущенный материал отмечен для закрепления. ' : ''}'
                        'Вы можете начать новую тему сейчас или позже.'
                  : 'Подтверждено ${confirmed.length} из ${check.checkedAtoms.length} проверенных элементов. '
                        'Тема пока закрыта. Подтверждённое сохранено; остальные знания можно закрепить в занятиях.',
            ),
            const Margin.vertical(16),
            MonoTextButton(
              title: passed ? 'Не сейчас' : 'Закрепить пробелы сейчас',
              onPressed: passed
                  ? () => Navigator.of(context).pop()
                  : () async {
                      await widget.controller.continueCourse();
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
          ] else if (!started)
            RuleCard(
              title: 'Перед темой «${widget.topic.title}»',
              text:
                  'Проверим только недостающие знания: ${check.questions.length} заданий. '
                  '${check.isCondensed ? 'Это короткая выборка: безошибочный результат откроет тему, ошибки сохранят только отдельно подтверждённые знания. ' : 'Каждый проверяемый элемент спрашивается дважды. '}Задания используют знакомые форматы курса. Формы хамзы отдельно не спрашиваются. Уже освоенное повторно сдавать не нужно. '
                  'Можно выйти: подтверждённые знания сохранятся.',
            )
          else if (concept != null)
            concept.explanationAsset != null
                ? ExplanationAssetCard(
                    asset: concept.explanationAsset!,
                    badge: 'Перед проверкой',
                  )
                : RuleCard(title: concept.label, badge: 'Перед проверкой')
          else if (question != null) ...[
            Text(
              'Задание ${index + 1} из ${check.questions.length}',
              style: UITextStyles.regular12.copyWith(
                color: UIColors.secondary2,
              ),
            ),
            const Margin.vertical(12),
            ExerciseChoiceQuestion(
              exercise: question,
              presentation: presentation!,
              cardKey: ValueKey('check.$index'),
              onPlay: mode == ExerciseMode.soundToLetter
                  ? () => _audio.playAsset(_audioSource.forAtom(question.atom))
                  : null,
              onAutoPlay: mode == ExerciseMode.soundToLetter
                  ? () => _audio.playAsset(_audioSource.forAtom(question.atom))
                  : null,
              autoPlay: mode == ExerciseMode.soundToLetter,
              track: _audio.track,
            ),
            const Margin.vertical(16),
            ValueListenableBuilder<OptionPlaybackState>(
              valueListenable: _optionAudio.state,
              builder: (context, playback, _) => Column(
                children: [
                  for (final (i, option) in question.options.indexed) ...[
                    ExerciseChoiceOption(
                      exercise: question,
                      presentation: presentation,
                      option: option,
                      index: i,
                      selected: selected == i,
                      revealed: false,
                      onTap: busy ? null : () => setState(() => selected = i),
                      playbackProgress: playback.progressAt(i),
                      isPlaying:
                          playback.activeIndex == i &&
                          _audio.track.value.isPlaying,
                      onPlay: mode == ExerciseMode.letterToSound
                          ? () => unawaited(
                              _optionAudio.toggle(
                                index: i,
                                asset: _audioSource.forAtom(option),
                              ),
                            )
                          : null,
                    ),
                    const Margin.vertical(8),
                  ],
                  if (mode == ExerciseMode.letterToSound)
                    MonoTextButton(
                      title: 'Прослушать ещё раз',
                      onPressed: () => unawaited(
                        _optionAudio.playAll(
                          question.options
                              .map(_audioSource.forAtom)
                              .toList(growable: false),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
