import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Плашка над заголовком карточки: «Новая тема», «Вопрос».
class BadgeLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final Widget? leading;
  final Widget? trailing;

  const BadgeLabel({
    required this.text,
    required this.color,
    this.textColor,
    this.leading,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: SquircleBorders.squircleBorder(
        color: color,
        borderRadius: 13,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(
            text,
            style: UITextStyles.monoMedium12.copyWith(color: textColor),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}
