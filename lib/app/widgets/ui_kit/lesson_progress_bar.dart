import 'package:flutter/widgets.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';

/// Полоса прогресса урока под шапкой: сколько букв набора уже пройдено.
class LessonProgressBar extends StatelessWidget {
  /// Заполнение от 0 до 1.
  final double value;

  final double height;

  /// Отладочная подпись рядом с полосой. В боевом интерфейсе не задаётся.
  final String? debugLabel;

  const LessonProgressBar({
    required this.value,
    this.height = 12,
    this.debugLabel,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: height,
      padding: const EdgeInsets.all(4),
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
        Text(debugLabel!, style: UITextStyles.hint),
      ],
    );
  }
}
