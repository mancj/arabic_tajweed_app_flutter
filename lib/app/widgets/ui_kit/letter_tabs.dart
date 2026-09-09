import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/segmented_tabs.dart';
import 'package:flutter/widgets.dart';

/// Полоса выбора буквы: все 28 глифов в порядке курикулума. В дорожку они
/// не помещаются, поэтому сегменты фиксированной ширины, а дорожка
/// прокручивается вбок.
class LetterTabs extends StatelessWidget {
  final List<String> glyphs;
  final int selected;
  final ValueChanged<int> onChanged;

  const LetterTabs({
    required this.glyphs,
    required this.selected,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  static const _style = TextStyle(
    fontFamily: UITextStyles.fontScheherazadeNew,
    fontSize: 22,
    color: UIColors.tealDark,
  );

  @override
  Widget build(BuildContext context) => SegmentedTabs(
    labels: glyphs,
    selected: selected,
    onChanged: onChanged,
    style: _style,
    segmentWidth: 48,
  );
}
