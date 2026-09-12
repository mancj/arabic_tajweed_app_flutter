import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/badge_label.dart';

/// Коробка карточки урока: плашка вида задания, заголовок и содержимое.
///
/// Ту же коробку рисует [LetterWidgetCard] — карточка вопроса, рядом с
/// которой эта и стоит в очереди заданий. Вынесено отдельно, чтобы вопросы
/// и задания не разъезжались по мелочам вроде радиуса, фона и тени.
class LessonCard extends StatelessWidget {
  final String badge;
  final String title;

  /// Кнопка в углу шапки — например «стереть» у обводки. Не задана —
  /// заголовок занимает всю ширину.
  final Widget? action;

  final Widget child;

  const LessonCard({
    required this.badge,
    required this.title,
    required this.child,
    this.action,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final action = this.action;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 24,
        borderSide: BorderSide(
          color: UIColors.highlightArea.withValues(alpha: .3),
        ),
        shadows: [
          BoxShadow(
            color: UIColors.shadows,
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BadgeLabel(text: badge, color: UIColors.text),
                    const Margin.vertical(8),
                    Text(title, style: UITextStyles.semibold22),
                  ],
                ),
              ),
              if (action != null) ...[const Margin.horizontal(12), action],
            ],
          ),
          const Margin.vertical(16),
          child,
        ],
      ),
    );
  }
}
