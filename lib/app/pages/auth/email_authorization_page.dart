import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../data/rest/api_exception.dart';
import '../../../data/rest/auth_rest_client.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/app_text_field.dart';
import 'email_auth_error.dart';
import 'email_code_page.dart';
import 'widgets/auth_notice.dart';
import 'widgets/auth_action.dart';
import 'widgets/email_auth_form.dart';

class EmailAuthorizationPage extends StatefulWidget {
  static const routeName = '/authorization/email';
  const EmailAuthorizationPage({super.key});

  @override
  State<EmailAuthorizationPage> createState() => _EmailAuthorizationPageState();
}

class _EmailAuthorizationPageState extends State<EmailAuthorizationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();
  final _cancelToken = CancelToken();
  bool _hasAttemptedSubmit = false;
  bool _busy = false;
  String? _notice;
  DateTime? _retryAt;
  Timer? _timer;

  int get _retrySeconds => _retryAt == null
      ? 0
      : (_retryAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 86400);

  @override
  void dispose() {
    _cancelToken.cancel();
    _timer?.cancel();
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

  Future<void> _requestCode() async {
    if (_busy || _retrySeconds > 0) return;
    setState(() {
      _hasAttemptedSubmit = true;
      _notice = null;
    });
    if (!_formKey.currentState!.validate()) {
      _emailFocus.requestFocus();
      return;
    }
    final email = _emailController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final challenge = await Get.find<AuthRestClient>().requestEmailCode(
        email,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      final loggedIn = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => EmailCodePage(email: email, challenge: challenge),
        ),
      );
      if (loggedIn == true && mounted) Navigator.of(context).pop(true);
    } on RequestCancelledException {
      // Уход со страницы отменяет ожидание, а не показывает сетевую ошибку.
    } catch (error) {
      if (!mounted) return;
      if (error is ClientErrorException && error.statusCode == 429) {
        _retryAt = DateTime.now().add(
          Duration(seconds: error.retryAfterSeconds ?? 60),
        );
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_retrySeconds == 0) timer.cancel();
          if (mounted) setState(() {});
        });
      }
      setState(() => _notice = emailAuthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EmailAuthForm(
    title: 'Войти с email',
    description: 'Пришлём одноразовый код на вашу почту.\nПароль не нужен.',
    iconAsset: UISVGAssets.mailAtSign,
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
            AppTextField(
              key: const ValueKey('email_authorization_email'),
              label: 'Email',
              hintText: 'name@example.com',
              controller: _emailController,
              focusNode: _emailFocus,
              enabled: !_busy,
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (_notice != null) setState(() => _notice = null);
              },
              onSubmitted: (_) => _requestCode(),
            ),
            const Margin.vertical(24),
            AuthAction(
              title: _busy
                  ? 'Отправляем…'
                  : _retrySeconds > 0
                  ? 'Повторить через $_retrySeconds с'
                  : 'Получить код',
              enabled: !_busy && _retrySeconds == 0,
              busy: _busy,
              onTap: _requestCode,
            ),
            if (_notice != null) ...[
              const Margin.vertical(24),
              AuthNotice(message: _notice!),
            ],
          ],
        ),
      ),
    ),
  );
}
