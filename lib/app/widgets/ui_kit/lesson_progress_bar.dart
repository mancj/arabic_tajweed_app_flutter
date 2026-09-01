import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';

/// Полоса прогресса урока под шапкой: сколько букв набора уже пройдено.
class LessonProgressBar extends StatelessWidget {
  /// Заполнение от 0 до 1.
  final double value;

  final double height;

  const LessonProgressBar({
    required this.value,
    this.height = 12,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: UIColors.iceBlue,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: UIColors.teal,
              borderRadius: BorderRadius.circular(height / 4),
            ),
          ),
        ),
      ),
    );
  }
}
