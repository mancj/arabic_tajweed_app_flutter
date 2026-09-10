import 'package:flutter/widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/badge_label.dart';

/// Карточка с правилом: плашка вида материала, заголовок темы и текст.
///
/// [badge] и [text] опциональны — у понятия без пояснения остаётся
/// один заголовок. [child] — слот под иллюстрацию к тексту, например
/// слово с подсвеченной буквой: карточка одна на все объяснения,
/// а что в ней показать, решает экран.
class RuleCard extends StatelessWidget {
  final String title;
  final String? badge;
  final String? text;
  final Widget? child;

  const RuleCard({
    required this.title,
    this.badge,
    this.text,
    this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final badge = this.badge;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 24,
        cornerSmoothing: 0,
        borderSide: const BorderSide(color: UIColors.highlightArea),
        shadows: const [
          BoxShadow(
            color: UIColors.shadows,
            offset: Offset(0, 4),
            blurRadius: 1.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            BadgeLabel(text: badge, color: UIColors.primary),
            const Margin.vertical(8),
          ],
          Text(title, style: UITextStyles.cardTitle),
          if (text != null && text.isNotEmpty) ...[
            const Margin.vertical(24),
            Text(text, style: UITextStyles.ruleBody),
          ],
          if (child != null) ...[
            const Margin.vertical(16),
            Center(child: child),
          ],
        ],
      ),
    );
  }
}
