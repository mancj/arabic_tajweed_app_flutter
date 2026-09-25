import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/letter_audio.dart';
import '../../../domain/atom.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/knowledge_check.dart';
import '../../../domain/lesson_pacing.dart';
import '../../../domain/progress_event.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/answer_option.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/question_card.dart';
import '../../widgets/ui_kit/rule_card.dart';
import 'course_controller.dart';

class KnowledgeCheckPage extends StatefulWidget {
  const KnowledgeCheckPage({
    required this.controller,
    required this.topic,
    super.key,
  });
  final CourseController controller;
  final Topic topic;
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
  final _audio = LetterAudio();
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
        if (check.isCondensed &&
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
        if (error == null && _scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
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
    final wordQuestion = question?.atom.kind == AtomKind.word;
    final target = widget.controller.statuses.firstWhere(
      (s) => s.topic.id == widget.topic.id,
    );
    return AppScaffold(
      title: 'Проверка знаний',
      bottomBar: NextButton(
        title: finished
            ? (passed ? 'Начать тему' : 'Закрепить пробелы')
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
                } else {
                  await widget.controller.continueCourse();
                }
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
          if (finished)
            RuleCard(
              title: passed ? 'Тема доступна' : 'Часть знаний подтверждена',
              text:
                  'Подтверждено: ${confirmed.length} из ${check.atoms.where((a) => a.kind != AtomKind.concept).length}. '
                  '${passed ? 'Можно начинать новое.' : 'Остальное закрепим в занятиях.'}',
            )
          else if (!started)
            RuleCard(
              title: 'Перед темой «${widget.topic.title}»',
              text:
                  'Проверим только недостающие знания: ${check.questions.length} заданий. '
                  '${check.isCondensed ? 'Это короткая выборка: безошибочный результат откроет тему, ошибки сохранят только отдельно подтверждённые знания. ' : 'Каждый элемент проверяется дважды. '}Уже освоенное повторно сдавать не нужно. '
                  'Можно выйти: подтверждённые знания сохранятся.',
            )
          else if (concept != null)
            RuleCard(
              title: concept.label,
              text: concept.note,
              badge: 'Перед проверкой',
            )
          else if (question != null) ...[
            Text(
              'Задание ${index + 1} из ${check.questions.length}',
              style: UITextStyles.regular12.copyWith(
                color: UIColors.secondary2,
              ),
            ),
            const Margin.vertical(12),
            QuestionCard(
              badge: 'Проверка',
              question: wordQuestion
                  ? 'Послушайте и выберите слово'
                  : question.reverse
                  ? 'Выберите написание'
                  : 'Выберите название',
              subject: wordQuestion
                  ? '♪'
                  : question.reverse
                  ? question.atom.label
                  : question.atom.display,
              subjectFont: wordQuestion || question.reverse
                  ? UITextStyles.fontOnest
                  : UITextStyles.fontScheherazadeNew,
            ),
            if (wordQuestion) ...[
              MonoTextButton(
                title: 'Прослушать слово',
                onPressed: () => _audio.playAsset(question.atom.audioAsset),
                icon: Icons.volume_up_rounded,
              ),
            ],
            const Margin.vertical(16),
            for (final (i, option) in question.options.indexed) ...[
              AnswerOption(
                selected: selected == i,
                onTap: busy
                    ? null
                    : () => setState(() {
                        selected = i;
                      }),
                child: Text(
                  wordQuestion || question.reverse
                      ? option.display
                      : option.label,
                  textDirection: wordQuestion || question.reverse
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: wordQuestion || question.reverse
                      ? UITextStyles.arabicRegular32
                      : UITextStyles.regular17,
                ),
              ),
              const Margin.vertical(8),
            ],
          ],
        ],
      ),
    );
  }
}
