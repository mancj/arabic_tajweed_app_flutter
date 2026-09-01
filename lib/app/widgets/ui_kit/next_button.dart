import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Кнопка перехода к следующему шагу с «подложкой» снизу: в макете нижняя
/// граница толще остальных.
///
/// [subtitle] опционален — без него заголовок центрируется по кнопке.
class NextButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Неактивная кнопка гасится, но остаётся на месте — иначе нижняя панель
  /// прыгает по высоте.
  final bool enabled;

  const NextButton({
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: Container(
          height: 62,
          padding: const EdgeInsets.fromLTRB(1, 1, 1, 6),
          decoration: SquircleBorders.squircleBorder(
            color: UIColors.tealDark,
            borderRadius: 16,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UIColors.teal,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: UITextStyles.fontOnest,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: UIColors.white,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: UITextStyles.fontOnest,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: UIColors.whiteHalf,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
