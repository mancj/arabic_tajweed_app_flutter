import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../resources/ui_resources.dart';
import 'next_button.dart';

enum SocialSignInProvider { google, apple }

/// Способы входа используют то же нейтральное стекло, что и кнопка главной.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    required this.provider,
    required this.onTap,
    super.key,
  });

  final SocialSignInProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isGoogle = provider == SocialSignInProvider.google;
      final title = isGoogle ? 'Войти с Google' : 'Войти с Apple';
      final text =
          TextPainter(
            text: TextSpan(text: title, style: UITextStyles.semibold16Compact),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(
            maxWidth: (constraints.maxWidth - 64).clamp(1, double.infinity),
          );
      // Подпись переносится при крупном тексте; капсула растёт вместе с ней.
      final height = (text.height + 32).clamp(56.0, double.infinity);
      text.dispose();

      return Semantics(
        button: true,
        label: title,
        onTap: onTap,
        excludeSemantics: true,
        child: NextButton(
          title: title,
          onTap: onTap,
          height: height,
          neutralBackground: true,
          leading: SvgPicture.asset(
            isGoogle ? UISVGAssets.google : UISVGAssets.appleLogo,
            width: 24,
            height: 24,
            colorFilter: isGoogle
                ? null
                : ColorFilter.mode(UIColors.text, BlendMode.srcIn),
          ),
        ),
      );
    },
  );
}
