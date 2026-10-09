import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../../data/rest/api_exception.dart';
import '../../../data/rest/auth_rest_client.dart';

import '../../resources/ui_resources.dart';
import '../../shared_state/auth_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/rule_card.dart';
import '../auth/authorization_page.dart';
import '../auth/email_auth_error.dart';
import '../auth/widgets/auth_notice.dart';
import '../auth/widgets/auth_action.dart';

class ProfilePage extends StatelessWidget {
  static const routeName = '/profile';

  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Профиль',
    builder: (context, insets) => SingleChildScrollView(
      padding: insets,
      child: Obx(
        () => Get.find<AuthState>().isAuthorized
            ? const _SessionCard()
            : const _AuthorizationCard(),
      ),
    ),
  );
}

class _AuthorizationCard extends StatelessWidget {
  const _AuthorizationCard();

  void _openAuthorization() {
    Get.toNamed<void>(AuthorizationPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return RuleCard(
      title: '',
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProfileArtwork(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ProfileHeading(),
                const Margin.vertical(12),
                Text(
                  'Войдите или создайте аккаунт, чтобы получить доступ ко всем функциям.',
                  style: UITextStyles.regular13.copyWith(
                    color: UIColors.text.withValues(alpha: .72),
                  ),
                ),
                const Margin.vertical(24),
                Semantics(
                  button: true,
                  label: 'Авторизация',
                  excludeSemantics: true,
                  onTap: _openAuthorization,
                  child: NextButton(
                    title: 'Авторизация',
                    onTap: _openAuthorization,
                    glassProminent: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeading extends StatelessWidget {
  const _ProfileHeading();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = UITextStyles.semibold26.copyWith(height: 1.2);
      final words = TextPainter(
        text: TextSpan(text: 'личный\nпрофиль.', style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = words.width <= constraints.maxWidth;
      words.dispose();

      return Semantics(
        header: true,
        child: Text(
          'Ваш личный\nпрофиль.',
          style: fits ? style : UITextStyles.semibold17,
        ),
      );
    },
  );
}

class _ProfileArtwork extends StatelessWidget {
  const _ProfileArtwork({this.label = 'Гость'});
  final String label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = (constraints.maxWidth * .5).clamp(168.0, 240.0);
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.65, -.3),
            radius: 1.3,
            colors: [
              Color.alphaBlend(UIColors.primary20, UIColors.inkSurface),
              UIColors.inkSurface,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -8,
              bottom: -8,
              right: 8,
              width: height + 16,
              child: const ExcludeSemantics(child: _IdentityIllustration()),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: UIColors.white10,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: UIColors.white20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.person,
                      size: 14,
                      color: UIColors.onInk,
                    ),
                    const Margin.horizontal(8),
                    Text(
                      label,
                      style: UITextStyles.semibold12.copyWith(
                        color: UIColors.onInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: ExcludeSemantics(
                child: Icon(
                  CupertinoIcons.sparkles,
                  size: 24,
                  color: UIColors.onInk.withValues(alpha: .65),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _IdentityIllustration extends StatelessWidget {
  const _IdentityIllustration();

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(UIImages.profileIdentity, fit: BoxFit.contain);
    if (kIsWeb || MediaQuery.disableAnimationsOf(context)) return image;

    // Фарфоровый пропуск мягко опускается на место и дальше неподвижен.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      child: image,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: Transform.rotate(angle: -.06 * (1 - value), child: child),
        ),
      ),
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard();
  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _busy = false;
  String? _notice;

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      try {
        await Get.find<AuthRestClient>().logout();
      } on UnauthorizedException {
        // Уже отозванный на сервере токен также удаляется с устройства.
      }
      await Get.find<AuthState>().setAuthToken(null);
    } catch (error) {
      if (mounted) setState(() => _notice = emailAuthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RuleCard(
    title: '',
    contentPadding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ProfileArtwork(label: 'Аккаунт'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Вы вошли', style: UITextStyles.semibold26),
              ),
              const Margin.vertical(12),
              Text(
                Get.find<AuthState>().email ?? 'Вход выполнен',
                style: UITextStyles.regular15,
              ),
              const Margin.vertical(24),
              AuthAction(
                title: _busy ? 'Выходим…' : 'Выйти из аккаунта',
                enabled: !_busy,
                busy: _busy,
                neutralBackground: true,
                onTap: _logout,
              ),
              if (_notice != null) ...[
                const Margin.vertical(16),
                AuthNotice(message: _notice!),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
