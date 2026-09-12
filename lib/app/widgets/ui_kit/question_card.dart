import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';

/// Карточка задания: плашка «Вопрос», формулировка и крупный предмет вопроса
/// на фоне из бледных форм буквы и чертежа её построения.
///
/// Фон разложен по координатам макета и привязан к краям карточки: чертёж
/// и бледные формы уходят за обрез, поэтому важно, где именно они его
/// пересекают.
class QuestionCard extends StatelessWidget {
  /// Высота карточки в макете.
  static const designHeight = 251.0;

  final String badge;
  final String question;

  /// Что показывают: глиф буквы или её название — зависит от режима.
  final String subject;

  /// Шрифт [subject]: у арабского глифа он свой.
  final String subjectFont;

  /// Бледные формы той же буквы справа. Без них фон остаётся с чертежом.
  final String? ghost;

  const QuestionCard({
    required this.badge,
    required this.question,
    required this.subject,
    this.subjectFont = UITextStyles.fontScheherazadeNew,
    this.ghost,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => LetterWidgetCard(
    labelText: badge,
    letter: subject,
    question: question,
    isArabic: subjectFont == UITextStyles.fontScheherazadeNew,
  );
}
