import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/haraka_match_question.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'exercise_tile.dart';
import 'letter_widget.dart';
import 'rule_card.dart';

/// Проверяет весь набор совпадений; число ответов и знак образца скрыты.
class HarakaMatchExercise extends StatelessWidget {
  const HarakaMatchExercise({
    required this.question,
    required this.selectedIds,
    required this.checked,
    required this.onToggle,
    required this.onPlay,
    required this.onAutoPlay,
    required this.track,
    super.key,
  });

  final HarakaMatchQuestion question;
  final Set<String> selectedIds;
  final bool checked;
  final ValueChanged<String> onToggle;
  final VoidCallback onPlay;
  final VoidCallback onAutoPlay;
  final ValueListenable<AudioTrack> track;

  @override
  Widget build(BuildContext context) {
    final answers = question.answerIds;
    final correct = question.isCorrect(selectedIds);
    final missing = answers.difference(selectedIds).isNotEmpty;
    final extra = selectedIds.difference(answers).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          key: ValueKey('haraka-match-prompt-${question.prompt.id}'),
          letter: question.prompt.id,
          glyph: Icon(Icons.hearing_rounded, size: 48, color: UIColors.primary),
          isArabic: false,
          labelText: 'Послушайте',
          question: 'Выберите все слоги с такой же огласовкой',
          onPlay: onPlay,
          onAutoPlay: onAutoPlay,
          track: track,
        ),
        const Margin.vertical(24),
        Text('Можно выбрать несколько плиток', style: UITextStyles.regular15),
        const Margin.vertical(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: question.options.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 82,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (_, index) {
            final atom = question.options[index];
            final selected = selectedIds.contains(atom.id);
            final accent = checked && answers.contains(atom.id)
                ? UIColors.success
                : checked && selected
                ? UIColors.error
                : null;
            return Semantics(
              key: ValueKey('haraka-match-option-${atom.id}'),
              label: 'Слог ${atom.display}',
              checked: selected,
              enabled: !checked,
              onTap: checked ? null : () => onToggle(atom.id),
              child: ExcludeSemantics(
                child: ExerciseChoiceTile(
                  glyph: atom.display,
                  index: index,
                  height: 82,
                  selected: selected,
                  accent: accent,
                  onTap: checked ? null : () => onToggle(atom.id),
                ),
              ),
            );
          },
        ),
        if (checked) ...[
          const Margin.vertical(24),
          RuleCard(
            badge: correct ? 'Верно' : 'Разбор',
            title: correct
                ? 'Все подходящие слоги найдены'
                : missing && extra
                ? 'Есть пропущенные и лишние слоги'
                : missing
                ? 'Не все подходящие слоги найдены'
                : 'Выбраны лишние слоги',
            text: correct
                ? 'В записи звучит ${question.prompt.display}. У выбранных слогов та же огласовка.'
                : 'В записи звучит ${question.prompt.display}. Нужные слоги: ${question.options.where((atom) => answers.contains(atom.id)).map((atom) => atom.display).join(' · ')}',
            badgeColor: correct ? UIColors.success : UIColors.error,
          ),
        ],
      ],
    );
  }
}
