import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

import 'lesson_controller.dart';

/// Итог урока или повторения со своей шапкой и действием закрытия.
class LessonFinishScreen extends StatelessWidget {
  const LessonFinishScreen({required this.controller, super.key});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final introduced = controller.sessionIntroduced;
    final isReview = controller.isReviewOnly;
    final exerciseCount = controller.completedExerciseCount;

    return AppScaffold(
      title: isReview ? 'Повторение' : 'Урок',
      bottomBar: NextButton(title: 'Закрыть', onTap: Get.back),
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Margin.vertical(24),
            _FinishHero(
              isReview: isReview,
              hasNewMaterial: introduced.isNotEmpty,
            ),
            if (exerciseCount > 0) ...[
              const Margin.vertical(16),
              _FinishStats(
                exerciseCount: exerciseCount,
                firstTryCount: controller.firstTryCorrectCount,
              ),
            ],
            const Margin.vertical(16),
            if (introduced.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Сегодня разобрали',
                      style: UITextStyles.semibold20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: UIColors.primary10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${introduced.length}',
                      style: UITextStyles.semibold14.copyWith(
                        color: UIColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Margin.vertical(12),
              for (final atom in introduced) ...[
                _LearnedTile(atom: atom),
                const Margin.vertical(8),
              ],
            ] else
              const _FinishReviewNote(),
            if (kDebugMode && controller.planReason.isNotEmpty) ...[
              const Margin.vertical(16),
              Text(
                'План: ${controller.planReason}',
                style: UITextStyles.monoMedium12.copyWith(
                  color: UIColors.secondary2,
                  fontFamilyFallback: [UITextStyles.fontDGFaseh],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinishHero extends StatelessWidget {
  const _FinishHero({required this.isReview, required this.hasNewMaterial});

  final bool isReview;
  final bool hasNewMaterial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.highlightArea,
        borderRadius: 28,
        borderSide: BorderSide(color: UIColors.borders),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: UIColors.primary10,
              border: Border.all(color: UIColors.primary30),
            ),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UIColors.primary,
              ),
              child: Icon(
                isReview ? Icons.refresh_rounded : Icons.check_rounded,
                size: 30,
                color: UIColors.white,
              ),
            ),
          ),
          const Margin.vertical(24),
          Text(
            'Занятие завершено',
            style: UITextStyles.semibold13.copyWith(color: UIColors.primary),
          ),
          const Margin.vertical(8),
          Text(
            isReview ? 'Повторение пройдено' : 'Урок пройден',
            style: UITextStyles.semibold29,
            textAlign: TextAlign.center,
          ),
          const Margin.vertical(8),
          Text(
            hasNewMaterial
                ? 'Вы познакомились с новым материалом. В следующих занятиях вернёмся к нему ещё раз.'
                : 'Вы завершили практику знакомого материала. Возвращайтесь к нему, чтобы закреплять знания.',
            style: UITextStyles.regular15.copyWith(color: UIColors.secondary2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FinishStats extends StatelessWidget {
  const _FinishStats({
    required this.exerciseCount,
    required this.firstTryCount,
  });

  final int exerciseCount;
  final int firstTryCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _FinishStat(value: '$exerciseCount', label: 'Выполнено заданий'),
      ),
      const Margin.horizontal(8),
      Expanded(
        child: _FinishStat(value: '$firstTryCount', label: 'С первого раза'),
      ),
    ],
  );
}

class _FinishStat extends StatelessWidget {
  const _FinishStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: SquircleBorders.squircleBorder(
      color: UIColors.cardBackground,
      borderRadius: 20,
      borderSide: BorderSide(color: UIColors.borders),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: UITextStyles.semibold27),
        const Margin.vertical(4),
        Text(
          label,
          style: UITextStyles.regular13.copyWith(color: UIColors.secondary2),
        ),
      ],
    ),
  );
}

class _FinishReviewNote extends StatelessWidget {
  const _FinishReviewNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: SquircleBorders.squircleBorder(
      color: UIColors.cardBackground,
      borderRadius: 24,
      borderSide: BorderSide(color: UIColors.borders),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.menu_book_rounded, size: 24, color: UIColors.primary),
        const Margin.horizontal(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сегодня повторили', style: UITextStyles.semibold17),
              const Margin.vertical(4),
              Text(
                'Новых элементов в этом занятии не было. Продолжайте практику, чтобы увереннее узнавать знакомые буквы и формы.',
                style: UITextStyles.regular15.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LearnedTile extends StatelessWidget {
  const _LearnedTile({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    final isConcept = atom.kind == AtomKind.concept;
    final category = switch (atom.kind) {
      AtomKind.letterForm => 'Буква и её форма',
      AtomKind.concept => 'Правило',
      AtomKind.haraka || AtomKind.sign => 'Знак',
      AtomKind.syllable => 'Слог',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 20,
        borderSide: BorderSide(color: UIColors.borders),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: SquircleBorders.squircleBorder(
              color: UIColors.primary10,
              borderRadius: 16,
            ),
            child: isConcept
                ? Icon(Icons.auto_stories_rounded, color: UIColors.primary)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        atom.display,
                        style: UITextStyles.arabicRegular48Compact.copyWith(
                          color: UIColors.primary,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
          ),
          const Margin.horizontal(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: UITextStyles.regular12.copyWith(
                    color: UIColors.secondary2,
                  ),
                ),
                const Margin.vertical(4),
                Text(
                  atom.label.isEmpty ? atom.display : atom.label,
                  style: UITextStyles.semibold17,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
