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
/// а что в ней показать, решает экран. [footer] доходит до боковых и
/// нижнего краёв карточки.
class RuleCard extends StatelessWidget {
  final String title;
  final String? badge;
  final String? text;
  final Widget? child;
  final Widget? footer;

  const RuleCard({
    required this.title,
    this.badge,
    this.text,
    this.child,
    this.footer,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final badge = this.badge;

    return Container(
      width: double.infinity,
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 24,
        cornerSmoothing: 0,
        borderSide: BorderSide(color: UIColors.borders),
        shadows: [
          BoxShadow(
            color: UIColors.shadows,
            offset: const Offset(0, 4),
            blurRadius: 1.5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, footer == null ? 24 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    BadgeLabel(
                      text: badge,
                      color: UIColors.primary,
                      textColor: UIColors.badgeText1,
                    ),
                    const Margin.vertical(8),
                  ],
                  Text(title, style: UITextStyles.semibold22),
                  if (text != null && text.isNotEmpty) ...[
                    const Margin.vertical(16),
                    Text(text, style: UITextStyles.regular15),
                  ],
                  if (child != null) ...[
                    const Margin.vertical(16),
                    Center(child: child),
                  ],
                ],
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}
