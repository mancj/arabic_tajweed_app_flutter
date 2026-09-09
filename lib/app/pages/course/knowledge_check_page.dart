import 'package:flutter/material.dart';

import '../../../domain/curriculum.dart';
import '../../../domain/knowledge_check.dart';
import '../../../domain/progress_event.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/answer_option.dart';
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
            at: DateTime.now(),
          ),
        );
        conceptIndex++;
      } else if (index < check.questions.length && selected != null) {
        final q = check.questions[index];
        final count =
            (correct[q.atom.id] ?? 0) + (selected == q.answerIndex ? 1 : 0);
        if (count == 2) {
          await widget.controller.repository.record(
            KnowledgeConfirmed(
              atomId: q.atom.id,
              sessionId: session!,
              at: DateTime.now(),
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
    final target = widget.controller.statuses.firstWhere(
      (s) => s.topic.id == widget.topic.id,
    );
    return AppScaffold(
      title: 'Проверка знаний',
      bottomBar: NextButton(
        title: finished
            ? (target.canPractice ? 'Начать тему' : 'Закрепить пробелы')
            : !started
            ? 'Начать проверку'
            : concept != null
            ? 'Понятно'
            : 'Ответить',
        enabled:
            !busy &&
            (finished || !started || concept != null || selected != null),
        onTap: finished
            ? () async {
                if (target.canPractice) {
                  await widget.controller.open(target);
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
            Text(error!, style: UITextStyles.regularText),
            const Margin.vertical(12),
          ],
          if (finished)
            RuleCard(
              title: target.canPractice
                  ? 'Тема доступна'
                  : 'Часть знаний подтверждена',
              text:
                  'Подтверждено: ${confirmed.length} из ${check.questions.length ~/ 2}. '
                  '${target.canPractice ? 'Можно начинать новое.' : 'Остальное закрепим в занятиях.'}',
            )
          else if (!started)
            RuleCard(
              title: 'Перед темой «${widget.topic.title}»',
              text:
                  'Проверим только недостающие знания: ${check.questions.length} заданий. '
                  'Каждый элемент проверяется дважды. Уже освоенное повторно сдавать не нужно. '
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
              style: UITextStyles.hint,
            ),
            const Margin.vertical(12),
            QuestionCard(
              badge: 'Проверка',
              question: question.reverse
                  ? 'Выберите написание'
                  : 'Выберите название',
              subject: question.reverse
                  ? question.atom.label
                  : question.atom.display,
              subjectFont: question.reverse
                  ? UITextStyles.fontOnest
                  : UITextStyles.fontScheherazadeNew,
            ),
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
                  question.reverse ? option.display : option.label,
                  textDirection: question.reverse
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: question.reverse
                      ? const TextStyle(
                          fontFamily: UITextStyles.fontScheherazadeNew,
                          fontSize: 32,
                          color: UIColors.text,
                        )
                      : UITextStyles.regularText,
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
