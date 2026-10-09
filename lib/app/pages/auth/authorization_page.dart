import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/google_identity_provider.dart';
import '../../../data/rest/api_exception.dart';
import '../../../data/rest/auth_rest_client.dart';
import '../../open_external_link.dart';
import '../../resources/ui_resources.dart';
import '../../shared_state/auth_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/social_sign_in_button.dart';
import 'email_authorization_page.dart';
import 'google_auth_error.dart';
import 'widgets/auth_notice.dart';

class AuthorizationPage extends StatefulWidget {
  static const routeName = '/authorization';

  const AuthorizationPage({super.key});

  @override
  State<AuthorizationPage> createState() => _AuthorizationPageState();
}

class _AuthorizationPageState extends State<AuthorizationPage> {
  static final _termsOfUse = Uri.parse(
    'https://share.note.sx/s45yarsj#6mS2BIZwSyl7iYHHQzuUYnYEBAza2IL/a1uQaSP+BC0',
  );
  static final _privacyPolicy = Uri.parse(
    'https://share.note.sx/b9ft76ir#/WtbEfFjv4BS5Bzk5zFLEIhkQgimmd7McYJI9xB7jgE',
  );

  final _noticeKey = GlobalKey();
  String? _notice;
  bool _busy = false;
  CancelToken? _request;

  void _showNotice(String message) {
    setState(() => _notice = message);
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

  Future<void> _signInGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final request = _request = CancelToken();
    try {
      final token = await Get.find<GoogleIdentityProvider>().signIn();
      if (!mounted || token == null) return;
      final session = await Get.find<AuthRestClient>().loginWithGoogle(
        token,
        cancelToken: request,
      );
      if (!mounted) return;
      await Get.find<AuthState>().setSession(session);
      if (mounted) Get.back(result: true);
    } catch (error) {
      if (mounted && error is! RequestCancelledException) {
        _showNotice(googleAuthErrorMessage(error));
      }
    } finally {
      _request = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _request?.cancel('Authorization page closed');
    super.dispose();
  }

  Future<void> _openEmail() async {
    if (_busy) return;
    setState(() => _notice = null);
    final loggedIn = await Get.toNamed<dynamic>(
      EmailAuthorizationPage.routeName,
    );
    if (loggedIn == true && mounted) Get.back(result: true);
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
                  'Войдите удобным способом, чтобы использовать все возможности приложения.',
                  textAlign: TextAlign.center,
                  style: UITextStyles.regular15.copyWith(
                    color: UIColors.text.withValues(alpha: .68),
                  ),
                ),
                const Margin.vertical(32),
                SocialSignInButton(
                  provider: SocialSignInProvider.google,
                  busy: _busy,
                  onTap: _signInGoogle,
                ),
                const Margin.vertical(12),
                SocialSignInButton(
                  provider: SocialSignInProvider.apple,
                  enabled: !_busy,
                  onTap: () {
                    if (!_busy) _showNotice('Вход с Apple скоро появится.');
                  },
                ),
                const Margin.vertical(16),
                const _AlternativeDivider(),
                const Margin.vertical(16),
                Semantics(
                  button: true,
                  label: 'Войти с email',
                  excludeSemantics: true,
                  enabled: !_busy,
                  onTap: _busy ? null : _openEmail,
                  child: NextButton(
                    title: 'Войти с email',
                    icon: CupertinoIcons.envelope,
                    glassProminent: true,
                    onTap: _openEmail,
                    enabled: !_busy,
                  ),
                ),
                const Margin.vertical(16),
                MonoTextButton(
                  title: 'Условия использования',
                  color: UIColors.text.withValues(alpha: .68),
                  onPressed: () =>
                      unawaited(openExternalLink(context, _termsOfUse)),
                ),
                MonoTextButton(
                  title: 'Политика конфиденциальности',
                  color: UIColors.text.withValues(alpha: .68),
                  onPressed: () =>
                      unawaited(openExternalLink(context, _privacyPolicy)),
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
                style: style.copyWith(color: UIColors.primary, height: 1.1),
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
        style: UITextStyles.monoRegular12.copyWith(
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
