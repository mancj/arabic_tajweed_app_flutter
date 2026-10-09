import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../data/rest/api_exception.dart';
import '../../../data/rest/auth_rest_client.dart';
import '../../../data/rest/email_auth.dart';
import '../../resources/ui_resources.dart';
import '../../shared_state/auth_state.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import 'email_auth_error.dart';
import 'widgets/auth_notice.dart';
import 'widgets/auth_action.dart';
import 'widgets/email_auth_form.dart';

class EmailCodePage extends StatefulWidget {
  const EmailCodePage({
    required this.email,
    required this.challenge,
    super.key,
  });
  final String email;
  final EmailCodeChallenge challenge;

  @override
  State<EmailCodePage> createState() => _EmailCodePageState();
}

class _EmailCodePageState extends State<EmailCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = PinInputController();
  final _cancelToken = CancelToken();
  late EmailCodeChallenge _challenge;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  DateTime? _verifyRetryAt;
  late Timer _timer;
  bool _busy = false;
  bool _resending = false;
  bool _submitted = false;
  String? _notice;
  String _lastInputCode = '';

  int _secondsUntil(DateTime? time) => time == null
      ? 0
      : (time.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
          0,
          86400,
        );
  int get _resendSeconds => _secondsUntil(_resendAt);
  int get _verifyRetrySeconds => _secondsUntil(_verifyRetryAt);
  bool get _expired => !DateTime.now().isBefore(_expiresAt);

  @override
  void initState() {
    super.initState();
    _setChallenge(widget.challenge);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _setChallenge(EmailCodeChallenge challenge) {
    _challenge = challenge;
    final now = DateTime.now();
    _expiresAt = now.add(Duration(seconds: challenge.expiresIn));
    _resendAt = now.add(Duration(seconds: challenge.resendAfter));
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _timer.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!mounted || _busy || _expired || _verifyRetrySeconds > 0) return;
    setState(() {
      _submitted = true;
      _notice = null;
    });
    if (!_formKey.currentState!.validate()) {
      _codeController.triggerError();
      _codeController.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final session = await Get.find<AuthRestClient>().verifyEmailCode(
        challengeId: _challenge.challengeId,
        code: _codeController.text,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      await Get.find<AuthState>().setSession(session);
      if (mounted) Navigator.of(context).pop(true);
    } on RequestCancelledException {
      // После ухода со страницы результат входа не применяется.
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.errorCode == 'INVALID_EMAIL_CODE') {
        _codeController.triggerError();
      }
      if (error is ClientErrorException && error.statusCode == 429) {
        _verifyRetryAt = DateTime.now().add(
          Duration(seconds: error.retryAfterSeconds ?? 60),
        );
      }
      setState(() => _notice = emailAuthErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onCodeChanged(String code) {
    // Поле уведомляет также об изменении выделения и фокуса.
    if (code == _lastInputCode) return;
    _lastInputCode = code;
    if (_notice != null) setState(() => _notice = null);
    if (code.length != 6) return;
    // Дождаться обновления формы и состояния внутри pin_code_fields.
    scheduleMicrotask(() {
      if (mounted && _codeController.text == code) {
        unawaited(_verifyCode());
      }
    });
  }

  Future<void> _resendCode() async {
    if (_busy || _resendSeconds > 0) return;
    setState(() {
      _busy = true;
      _resending = true;
      _notice = null;
    });
    try {
      final challenge = await Get.find<AuthRestClient>().requestEmailCode(
        widget.email,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _setChallenge(challenge);
        _codeController.clear();
        _submitted = false;
        _notice = 'Новый код отправлен. Используйте последнее письмо.';
      });
      _codeController.requestFocus();
    } on RequestCancelledException {
      // Экран уже закрыт.
    } catch (error) {
      if (!mounted) return;
      if (error is ClientErrorException && error.statusCode == 429) {
        _resendAt = DateTime.now().add(
          Duration(seconds: error.retryAfterSeconds ?? 60),
        );
      }
      setState(() => _notice = emailAuthErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = !_busy && !_expired && _verifyRetrySeconds == 0;
    return EmailAuthForm(
      title: 'Введите код',
      description: 'Отправили 6-значный код на\n${widget.email}',
      iconAsset: UISVGAssets.shieldFillCheck,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Text('Код из письма', style: UITextStyles.semibold13),
              ),
              const Margin.vertical(8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final reduceMotion = MediaQuery.disableAnimationsOf(context);
                  final style = UITextStyles.semibold22;
                  final cellWidth = ((constraints.maxWidth - 8 * 5) / 6).clamp(
                    1.0,
                    56.0,
                  );
                  final cellHeight = math.max(
                    56.0,
                    MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                            (style.height ?? 1) +
                        24,
                  );
                  // Пакет управляет жестами редактирования и вставки текста.
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: MaterialPinFormField(
                      key: const ValueKey('email_authorization_code'),
                      length: 6,
                      pinController: _codeController,
                      semanticLabel: 'Код из письма, 6 цифр',
                      enabled: !_busy,
                      readOnly: _busy,
                      autoFocus: true,
                      autoDismissKeyboard: false,
                      enableHapticFeedback: false,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      enableAutofill: true,
                      autofillContextAction: AutofillContextAction.cancel,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      scrollPadding: const EdgeInsets.all(24),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      theme: MaterialPinTheme(
                        cellSize: Size(cellWidth, cellHeight),
                        spacing: 8,
                        borderRadius: BorderRadius.circular(12),
                        textStyle: style,
                        fillColor: UIColors.highlightArea,
                        focusedFillColor: UIColors.primary10,
                        filledFillColor: UIColors.highlightArea,
                        completeFillColor: UIColors.highlightArea,
                        borderColor: UIColors.transparent,
                        focusedBorderColor: UIColors.primary,
                        filledBorderColor: UIColors.transparent,
                        completeBorderColor: UIColors.primary,
                        errorColor: UIColors.error,
                        errorBorderColor: UIColors.error,
                        errorFillColor: UIColors.error.withValues(alpha: .08),
                        cursorColor: UIColors.primary,
                        animateCursor: !reduceMotion,
                        enableErrorShake: !reduceMotion,
                        entryAnimation: reduceMotion
                            ? MaterialPinAnimation.none
                            : MaterialPinAnimation.fade,
                        animationDuration: reduceMotion
                            // AnimatedSize пакета падает при нулевой длительности
                            // во время появления ошибки; 1 мс даёт мгновенную смену.
                            ? const Duration(milliseconds: 1)
                            : const Duration(milliseconds: 150),
                      ),
                      formErrorStyle: UITextStyles.regular13.copyWith(
                        color: UIColors.error,
                      ),
                      autovalidateMode: _submitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : 'Введите 6 цифр из письма',
                      onChanged: _onCodeChanged,
                      onSubmitted: (_) => _verifyCode(),
                    ),
                  );
                },
              ),
              const Margin.vertical(16),
              Text(
                _expired
                    ? 'Срок кода истёк. Запросите новый код.'
                    : 'Код действует 5 минут. Проверьте также папку «Спам».',
                style: UITextStyles.regular13,
              ),
              const Margin.vertical(24),
              AuthAction(
                title: _busy && !_resending
                    ? 'Входим…'
                    : _verifyRetrySeconds > 0
                    ? 'Повторить через $_verifyRetrySeconds с'
                    : 'Войти',
                enabled: canVerify,
                busy: _busy && !_resending,
                onTap: _verifyCode,
              ),
              const Margin.vertical(16),
              MonoTextButton(
                title: _resending
                    ? 'Отправляем…'
                    : _resendSeconds > 0
                    ? 'Отправить снова через $_resendSeconds с'
                    : 'Отправить код снова',
                onPressed: !_busy && _resendSeconds == 0 ? _resendCode : null,
              ),
              MonoTextButton(
                title: 'Изменить email',
                onPressed: !_busy ? () => Navigator.of(context).pop() : null,
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
}
