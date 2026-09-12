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

  /// Ширина сегмента. Не задана — сегменты делят дорожку поровну. Задана —
  /// дорожка прокручивается вбок: так в неё помещаются все 28 букв.
  final double? segmentWidth;

  const SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.style,
    this.selectedStyle,
    this.height = 44,
    this.segmentWidth,
    Key? key,
  }) : super(key: key);

  static const _trackPadding = 3.0;

  TextStyle get _style =>
      style ?? UITextStyles.medium15.copyWith(color: UIColors.secondary2);

  TextStyle get _selectedStyle =>
      selectedStyle ?? _style.copyWith(color: UIColors.highlightArea);

  @override
  Widget build(BuildContext context) {
    final width = segmentWidth;

    return Container(
      height: height,
      padding: const EdgeInsets.all(_trackPadding),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.highlightArea,
        borderRadius: 16,
        borderSide: BorderSide(color: UIColors.borders, width: 0.6),
        shadows: [
          BoxShadow(
            color: UIColors.shadows,
            offset: Offset(0, 3),
            blurRadius: 1.5,
          ),
        ],
      ),
      child: width == null
          ? Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(child: _segment(i)),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    SizedBox(width: width, child: _segment(i)),
                ],
              ),
            ),
    );
  }

  Widget _segment(int i) => GestureDetector(
    onTap: () => onChanged(i),
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: i == selected ? UIColors.secondary1 : null,
        borderRadius: BorderRadius.circular(16 - _trackPadding * 2),
      ),
      child: Text(
        labels[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: i == selected ? _selectedStyle : _style,
      ),
    ),
  );
}
