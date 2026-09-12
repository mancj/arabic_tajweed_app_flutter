import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Плашка над заголовком карточки: «Новая тема», «Вопрос».
class BadgeLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;

  const BadgeLabel({
    required this.text,
    required this.color,
    this.textColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: SquircleBorders.squircleBorder(
        color: color,
        borderRadius: 13,
      ),
      child: Text(
        text,
        style: UITextStyles.badge.copyWith(
          color: textColor,
          fontFamily: UITextStyles.fontJetBrainsMono,
        ),
      ),
    );
  }
}
