import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../resources/ui_resources.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/margin.dart';
import '../../../widgets/ui_kit/rule_card.dart';

/// Общая карточка двух шагов входа; форма остаётся доступной при клавиатуре
/// и увеличенном системном тексте.
class EmailAuthForm extends StatelessWidget {
  const EmailAuthForm({
    required this.title,
    required this.description,
    required this.child,
    this.iconAsset,
    super.key,
  });
  final String title;
  final String description;
  final Widget child;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Почта',
    builder: (context, insets) => SingleChildScrollView(
      padding: insets,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RuleCard(
            title: '',
            contentPadding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: UIColors.primary10,
                      ),
                      child: Center(
                        child: iconAsset != null
                            ? SvgPicture.asset(
                                iconAsset!,
                                width: 36,
                                height: 36,
                                colorFilter: ColorFilter.mode(
                                  UIColors.primary,
                                  BlendMode.srcIn,
                                ),
                              )
                            : Icon(
                                CupertinoIcons.envelope_badge,
                                size: 36,
                                color: UIColors.primary,
                              ),
                      ),
                    ),
                  ),
                ),
                const Margin.vertical(24),
                Semantics(
                  header: true,
                  child: Text(title, style: UITextStyles.semibold26),
                ),
                const Margin.vertical(8),
                Text(
                  description,
                  style: UITextStyles.regular15.copyWith(
                    color: UIColors.text.withValues(alpha: .72),
                  ),
                ),
                const Margin.vertical(32),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
