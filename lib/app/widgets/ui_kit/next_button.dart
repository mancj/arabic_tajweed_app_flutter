import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/inner_shadow.dart';

/// Кнопка перехода к следующему шагу. Стиль один в один с макетом: градиент
/// сверху вниз, мягкая многослойная тень под кнопкой и две внутренние тени —
/// светлая подсветка и тёмная фаска по нижнему краю.
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

  static final _borderRadius = BorderRadius.circular(16);

  /// Тени под кнопкой из макета: (прозрачность, сдвиг вниз, размытие).
  static const _shadows = [
    (0.15, 3.0, 7.0),
    (0.1, 1.0, 3.0),
    (0.09, 6.0, 6.0),
    (0.05, 13.0, 8.0),
    (0.02, 24.0, 10.0),
  ];

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [UIColors.orange, UIColors.orangeButtonBottom],
              stops: [0.234, 1],
            ),
            boxShadow: [
              for (final (alpha, dy, blur) in _shadows)
                BoxShadow(
                  color: UIColors.buttonShadow.withValues(alpha: alpha),
                  offset: Offset(0, dy),
                  blurRadius: blur,
                ),
            ],
          ),
          child: InnerShadows(
            borderRadius: _borderRadius,
            shadows: [
              InnerShadow(
                color: UIColors.buttonShadow.withOpacity(0.2),
                offset: const Offset(0, -3),
                blur: 6,
              ),
              const InnerShadow(
                color: UIColors.orangeInnerHighlight,
                offset: Offset(0, -3),
                blur: 2,
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: UITextStyles.fontOnest,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.2,
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
                      height: 1.2,
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
