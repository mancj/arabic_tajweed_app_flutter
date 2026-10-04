import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/data/rest/syllable_check.dart';
import 'package:flutter/material.dart';

import 'letter_widget.dart';
import 'rule_card.dart';

/// Карточка чтения: образец звучания не предъявляется до ответа ученика.
class SyllablePronunciationExercise extends StatelessWidget {
  const SyllablePronunciationExercise({
    required this.glyph,
    this.result,
    this.error,
    this.showFeedback = true,
    super.key,
  });

  final String glyph;
  final SyllableCheck? result;
  final String? error;
  final bool showFeedback;

  @override
  Widget build(BuildContext context) {
    final check = result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          letter: glyph,
          isArabic: true,
          labelText: 'Прочитайте',
          question: 'Прочитайте этот слог вслух',
          showPlay: false,
        ),
        if (error != null) ...[
          const Margin.vertical(24),
          RuleCard(badge: 'Проверка недоступна', title: error!),
        ] else if (showFeedback && check != null) ...[
          const Margin.vertical(24),
          RuleCard(
            badge: switch (check.status) {
              SyllableCheckStatus.matched => 'Верно',
              SyllableCheckStatus.mismatch => 'Попробуйте ещё раз',
              SyllableCheckStatus.unclear => 'Повторите запись',
            },
            title: check.feedbackTitle,
            text: check.hint,
            badgeColor: switch (check.status) {
              SyllableCheckStatus.matched => UIColors.success,
              SyllableCheckStatus.mismatch => UIColors.error,
              SyllableCheckStatus.unclear => UIColors.secondary2,
            },
            child: check.canEvaluate && check.heard != null
                ? Text(
                    check.heard!,
                    textDirection: TextDirection.rtl,
                    style: UITextStyles.arabicRegular48Compact,
                  )
                : null,
          ),
        ],
      ],
    );
  }
}
