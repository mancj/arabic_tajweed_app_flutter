import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/social_sign_in_button.dart';
import 'email_authorization_page.dart';
import 'widgets/auth_notice.dart';

class AuthorizationPage extends StatefulWidget {
  static const routeName = '/authorization';

  const AuthorizationPage({super.key});

  @override
  State<AuthorizationPage> createState() => _AuthorizationPageState();
}

class _AuthorizationPageState extends State<AuthorizationPage> {
  final _noticeKey = GlobalKey();
  String? _notice;

  void _chooseProvider(SocialSignInProvider provider) {
    final name = provider == SocialSignInProvider.google ? 'Google' : 'Apple';
    setState(() => _notice = 'Вход с $name скоро появится.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final noticeContext = _noticeKey.currentContext;
      if (!mounted || noticeContext == null) return;
      Scrollable.ensureVisible(
        noticeContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openEmail() {
    setState(() => _notice = null);
    Get.toNamed<void>(EmailAuthorizationPage.routeName);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Вход',
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    builder: (context, insets) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: insets,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              minHeight: (constraints.maxHeight - insets.vertical).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WelcomeArtwork(compact: constraints.maxHeight < 700),
                const Margin.vertical(16),
                const _WelcomeHeading(),
                const Margin.vertical(12),
                Text(
                  'Войдите удобным способом.\nПароль не понадобится.',
                  textAlign: TextAlign.center,
                  style: UITextStyles.regular15.copyWith(
                    color: UIColors.text.withValues(alpha: .68),
                  ),
                ),
                const Margin.vertical(32),
                SocialSignInButton(
                  provider: SocialSignInProvider.google,
                  onTap: () => _chooseProvider(SocialSignInProvider.google),
                ),
                const Margin.vertical(12),
                SocialSignInButton(
                  provider: SocialSignInProvider.apple,
                  onTap: () => _chooseProvider(SocialSignInProvider.apple),
                ),
                const Margin.vertical(16),
                const _AlternativeDivider(),
                const Margin.vertical(16),
                Semantics(
                  button: true,
                  label: 'Войти с email',
                  excludeSemantics: true,
                  onTap: _openEmail,
                  child: NextButton(
                    title: 'Войти с email',
                    icon: CupertinoIcons.envelope,
                    glassProminent: true,
                    onTap: _openEmail,
                  ),
                ),
                const Margin.vertical(24),
                Text(
                  'Один аккаунт для вашего пути в арабском.',
                  textAlign: TextAlign.center,
                  style: UITextStyles.regular12.copyWith(
                    color: UIColors.text.withValues(alpha: .6),
                  ),
                ),
                if (_notice != null) ...[
                  const Margin.vertical(16),
                  AuthNotice(key: _noticeKey, message: _notice!),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeHeading extends StatelessWidget {
  const _WelcomeHeading();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      bool fits(TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: 'Продолжим', style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        return fits;
      }

      // Сохраняем целое слово и системное увеличение, выбирая готовый стиль.
      final style =
          [
            UITextStyles.semibold32,
            UITextStyles.semibold26,
            UITextStyles.semibold22,
            UITextStyles.semibold20,
          ].firstWhereOrNull(fits) ??
          UITextStyles.semibold17;
      return Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            text: 'Продолжим\n',
            children: [
              TextSpan(
                text: 'ваш путь.',
                style: style.copyWith(color: UIColors.studyAccent),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
      );
    },
  );
}

class _AlternativeDivider extends StatelessWidget {
  const _AlternativeDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ColoredBox(
          color: UIColors.text.withValues(alpha: .1),
          child: const SizedBox(height: 1),
        ),
      ),
      const Margin.horizontal(16),
      Text(
        'или',
        style: UITextStyles.regular12.copyWith(
          color: UIColors.text.withValues(alpha: .55),
        ),
      ),
      const Margin.horizontal(16),
      Expanded(
        child: ColoredBox(
          color: UIColors.text.withValues(alpha: .1),
          child: const SizedBox(height: 1),
        ),
      ),
    ],
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 128.0 : 184.0;
    final artwork = SizedBox(
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [UIColors.primary20, UIColors.transparent],
              ),
            ),
          ),
          Image.asset(
            UIImages.profileIdentity,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
    if (kIsWeb || MediaQuery.disableAnimationsOf(context)) {
      return ExcludeSemantics(child: artwork);
    }
    // Фарфоровый пропуск один раз мягко опускается на место; не отвлекает от входа.
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        child: artwork,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: Transform.rotate(angle: -.08 * (1 - value), child: child),
          ),
        ),
      ),
    );
  }
}
