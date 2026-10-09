import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_check.dart';
import 'package:flutter/material.dart';

import 'letter_widget.dart';
import 'rule_card.dart';

/// Карточка чтения: образец звучания не предъявляется до ответа ученика.
class PronunciationExercise extends StatelessWidget {
  const PronunciationExercise({
    required this.glyph,
    this.result,
    this.prompt = 'Прочитайте этот слог вслух',
    this.error,
    this.showFeedback = true,
    this.showRawHeard = false,
    super.key,
  });

  final String glyph;
  final String prompt;
  final PronunciationCheck? result;
  final String? error;
  final bool showFeedback;
  final bool showRawHeard;

  @override
  Widget build(BuildContext context) {
    final check = result;
    final heard = showRawHeard ? check?.rawHeard ?? check?.heard : check?.heard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterWidgetCard(
          letter: glyph,
          isArabic: true,
          labelText: 'Произношение',
          question: prompt,
          showPlay: false,
        ),
        if (error != null) ...[
          const Margin.vertical(24),
          RuleCard(badge: 'Проверка недоступна', title: error!),
        ] else if (showFeedback && check != null) ...[
          const Margin.vertical(24),
          RuleCard(
            badge: switch (check.status) {
              PronunciationStatus.matched => 'Верно',
              PronunciationStatus.mismatch => 'Попробуйте ещё раз',
              PronunciationStatus.unclear => 'Повторите запись',
            },
            title: check.feedbackTitle,
            text: check.hint,
            badgeColor: switch (check.status) {
              PronunciationStatus.matched => UIColors.success,
              PronunciationStatus.mismatch => UIColors.error,
              PronunciationStatus.unclear => UIColors.secondary2,
            },
            child: showRawHeard
                ? Column(
                    children: [
                      Text('Сервер услышал', style: UITextStyles.regular15),
                      const Margin.vertical(8),
                      if (heard != null && heard.trim().isNotEmpty)
                        Text(
                          heard,
                          textDirection: TextDirection.rtl,
                          style: UITextStyles.arabicRegular48Compact,
                        )
                      else
                        Text(
                          'Нет распознанного текста',
                          style: UITextStyles.regular15,
                        ),
                    ],
                  )
                : check.canEvaluate && heard != null
                ? Text(
                    heard,
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
