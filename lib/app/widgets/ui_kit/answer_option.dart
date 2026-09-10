import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Вариант ответа: радиокнопка, пунктирный разделитель и содержимое.
///
/// [accent] красит радиокнопку — им же подсвечивается верный и неверный
/// ответ после проверки.
class AnswerOption extends StatelessWidget {
  final Widget child;
  final bool selected;
  final Color? accent;
  final VoidCallback? onTap;

  const AnswerOption({
    required this.child,
    this.selected = false,
    this.accent,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: SquircleBorders.squircleBorder(
          color: UIColors.cardBackground,
          borderRadius: 18,
          borderSide: BorderSide(color: UIColors.borders),
          // Выбранный вариант в макете чуть приподнят над списком.
          shadows: selected
              ? [
                  BoxShadow(
                    color: UIColors.shadows,
                    offset: Offset(0, 2),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _Radio(selected: selected, accent: accent ?? UIColors.primary),
            const Margin.horizontal(12),
            RotatedBox(
              quarterTurns: 1,
              child: SvgPicture.asset(UISVGAssets.dashedDivider, width: 22),
            ),
            const Margin.horizontal(12),
            Expanded(child: child),
            const Margin.horizontal(8),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 21,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Рамка на выборе коротко «щёлкает»: без неё отклик читается
          // только по заливке, которая появляется позже.
          Container(
                decoration: SquircleBorders.squircleBorder(
                  color: UIColors.transparent,
                  borderRadius: 8,
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              )
              .animate(target: selected ? 1 : 0)
              .scaleXY(end: 1.12, duration: 110.ms, curve: Curves.easeOutBack)
              .then()
              .scaleXY(end: 1 / 1.12, duration: 170.ms, curve: Curves.easeOut),
          SizedBox.square(
                dimension: 13,
                child: Container(
                  decoration: SquircleBorders.squircleBorder(
                    color: accent,
                    borderRadius: 5,
                  ),
                ),
              )
              .animate(target: selected ? 1 : 0)
              .fadeIn(duration: 120.ms)
              .scaleXY(begin: .3, duration: 260.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}
