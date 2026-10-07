import 'package:flutter/cupertino.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/app_text_field.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/rule_card.dart';
import 'widgets/auth_notice.dart';

class EmailAuthorizationPage extends StatefulWidget {
  static const routeName = '/authorization/email';

  const EmailAuthorizationPage({super.key});

  @override
  State<EmailAuthorizationPage> createState() => _EmailAuthorizationPageState();
}

class _EmailAuthorizationPageState extends State<EmailAuthorizationPage> {
  final _formKey = GlobalKey<FormState>();
  final _noticeKey = GlobalKey();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _hasAttemptedSubmit = false;
  bool _showNotice = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Введите email';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Проверьте формат email';
    }
    return null;
  }

  void _clearNotice(String _) {
    if (_showNotice) setState(() => _showNotice = false);
  }

  void _requestCode() {
    setState(() {
      _hasAttemptedSubmit = true;
      _showNotice = false;
    });
    if (!_formKey.currentState!.validate()) {
      _emailFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _showNotice = true);
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
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Form(
                key: _formKey,
                autovalidateMode: _hasAttemptedSubmit
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
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
                          child: Icon(
                            CupertinoIcons.envelope_badge,
                            size: 36,
                            color: UIColors.studyAccent,
                          ),
                        ),
                      ),
                    ),
                    const Margin.vertical(24),
                    Semantics(
                      header: true,
                      child: Text(
                        'Войти с email',
                        style: UITextStyles.semibold26,
                      ),
                    ),
                    const Margin.vertical(8),
                    Text(
                      'Пришлём одноразовый код на вашу почту.\nПароль не нужен.',
                      style: UITextStyles.regular15.copyWith(
                        color: UIColors.text.withValues(alpha: .72),
                      ),
                    ),
                    const Margin.vertical(32),
                    AppTextField(
                      key: const ValueKey('email_authorization_email'),
                      label: 'Email',
                      hintText: 'name@example.com',
                      controller: _emailController,
                      focusNode: _emailFocus,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      onChanged: _clearNotice,
                      onSubmitted: (_) => _requestCode(),
                    ),
                    const Margin.vertical(24),
                    Semantics(
                      button: true,
                      label: 'Получить код',
                      excludeSemantics: true,
                      onTap: _requestCode,
                      child: NextButton(
                        title: 'Получить код',
                        glassProminent: true,
                        onTap: _requestCode,
                      ),
                    ),
                    if (_showNotice) ...[
                      const Margin.vertical(24),
                      AuthNotice(
                        key: _noticeKey,
                        message:
                            'Вход по email скоро появится. Пока код не отправлен.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
