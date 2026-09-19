import 'package:flutter/widgets.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';

/// Полоса прогресса урока под шапкой: сколько букв набора уже пройдено.
class LessonProgressBar extends StatelessWidget {
  /// Заполнение от 0 до 1.
  final double value;

  final double height;

  /// Волнистая полоса для упражнений.
  final bool wavy;

  /// Плавно менять заполнение, оставляя рисунок волны неподвижным.
  final bool animateOnChange;

  /// Отладочная подпись рядом с полосой. В боевом интерфейсе не задаётся.
  final String? debugLabel;

  const LessonProgressBar({
    required this.value,
    this.height = 12,
    this.wavy = false,
    this.animateOnChange = true,
    this.debugLabel,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget bar = wavy
        ? animateOnChange
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: value, end: value),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOutBack,
                  builder: (context, animatedValue, _) => TickerMode(
                    enabled: false,
                    child: _expressiveBar(animatedValue),
                  ),
                )
              : _expressiveBar(value)
        : Container(
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: UIColors.backgroundShapes2,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: UIColors.primary,
                    borderRadius: BorderRadius.circular(height / 4),
                  ),
                ),
              ),
            ),
          );

    if (debugLabel == null) return bar;
    return Row(
      children: [
        Expanded(child: bar),
        const Margin.horizontal(8),
        Text(
          debugLabel!,
          style: UITextStyles.regular12.copyWith(color: UIColors.secondary2),
        ),
      ],
    );
  }

  Widget _expressiveBar(double progress) => ExpressiveLinearProgressIndicator(
    value: progress,
    color: UIColors.primary,
    backgroundColor: UIColors.backgroundShapes2,
    minHeight: height,
    gapSize: 0,
    indicatorStrokeWidth: height / 3,
    trackStrokeWidth: height / 4,
    amplitude: .5,
  );
}
