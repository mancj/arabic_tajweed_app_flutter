import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Переключатель «один из нескольких»: белая дорожка, выбранный сегмент залит
/// бирюзовым. Одним виджетом набраны и режимы обводки, и выбор буквы —
/// отличаются только подписями и их начертанием.
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Начертание невыбранных сегментов; у выбранного берётся [selectedStyle].
  final TextStyle? style;
  final TextStyle? selectedStyle;

  final double height;

  const SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.style,
    this.selectedStyle,
    this.height = 44,
    Key? key,
  }) : super(key: key);

  static const _trackPadding = 3.0;

  TextStyle get _style =>
      style ??
      const TextStyle(
        fontFamily: UITextStyles.fontOnest,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: UIColors.tealDark,
      );

  TextStyle get _selectedStyle =>
      selectedStyle ?? _style.copyWith(color: UIColors.white);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(_trackPadding),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.white,
        borderRadius: 16,
        borderSide: const BorderSide(color: UIColors.cardBorder, width: 0.6),
        shadows: const [
          BoxShadow(
            color: UIColors.cardShadowSoft,
            offset: Offset(0, 3),
            blurRadius: 1.5,
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? UIColors.teal : null,
                    borderRadius: BorderRadius.circular(16 - _trackPadding * 2),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: i == selected ? _selectedStyle : _style,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
