// Защищает настоящий путь из профиля: письмо запрашивается до экрана кода,
// ведущие нули сохраняются, сессия переживает перезапуск, выход отзывает токен.
// Ошибки и повторная отправка не должны применять старый challenge или дать вход.
import 'dart:async';

import 'package:arabic_tajweed_app/app/pages/auth/authorization_page.dart';
import 'package:arabic_tajweed_app/app/pages/auth/email_authorization_page.dart';
import 'package:arabic_tajweed_app/app/pages/auth/email_code_page.dart';
import 'package:arabic_tajweed_app/app/pages/profile/profile_page.dart';
import 'package:arabic_tajweed_app/app/shared_state/auth_state.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/mono_text_button.dart';
import 'package:arabic_tajweed_app/data/rest/auth_rest_client.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late SharedPreferenceManager preferences;
  late AuthState auth;
  late List<RequestOptions> requests;
  late Object Function(RequestOptions) reply;
  Completer<Object>? pending;
  int status = 200;
  Map<String, List<String>> headers = {};
  var challengeSequence = 0;
  var resendAfter = 60;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    preferences = SharedPreferenceManager(
      await SharedPreferences.getInstance(),
    );
    auth = AuthState(preferences);
    Get.put(auth);
    requests = [];
    pending = null;
    status = 200;
    headers = {};
    challengeSequence = 0;
    resendAfter = 60;
    reply = (options) => switch (options.path) {
      '/auth/email/request-code' => {
        'challenge_id': 'challenge-${++challengeSequence}',
        'expires_in': 300,
        'resend_after': resendAfter,
      },
      '/auth/email/verify-code' => {
        'uuid': 'user-1',
        'email': 'user@example.com',
        'authToken': 'test-token',
        'isEmailVerified': true,
      },
      _ => '',
    };
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          final data = pending == null ? reply(options) : await pending!.future;
          final response = Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: data,
            headers: Headers.fromMap(headers),
          );
          if (status >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(response);
          }
        },
      ),
    );
    Get.put(AuthRestClient(dio: dio));
  });
  tearDown(() async {
    dio.close(force: true);
    Get.reset();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool profile = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: profile
            ? ProfilePage.routeName
            : EmailAuthorizationPage.routeName,
        getPages: [
          GetPage(name: ProfilePage.routeName, page: () => const ProfilePage()),
          GetPage(
            name: AuthorizationPage.routeName,
            page: () => const AuthorizationPage(),
          ),
          GetPage(
            name: EmailAuthorizationPage.routeName,
            page: () => const EmailAuthorizationPage(),
          ),
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> requestCode(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('email_authorization_email')),
      'user@example.com',
    );
    await tap(tester, 'Получить код');
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'profile login preserves leading zeroes and session; logout returns to guest',
    (tester) async {
      await mount(tester, profile: true);
      await tap(tester, 'Авторизация');
      await tap(tester, 'Войти с email');
      await requestCode(tester);
      expect(find.byType(EmailCodePage), findsOneWidget);
      expect(requests.single.path, '/auth/email/request-code');
      expect(requests.single.data, {'email': 'user@example.com'});
      await tester.enterText(
        find.byKey(const ValueKey('email_authorization_code')),
        '000123',
      );
      await tester.pumpAndSettle();
      expect(requests.last.data['code'], '000123');
      expect(requests.last.data['challenge_id'], 'challenge-1');
      expect(find.text('Вы вошли'), findsOneWidget);
      expect(find.byType(EmailCodePage), findsNothing);
      final restarted = AuthState(preferences);
      expect(restarted.authToken, 'test-token');
      expect(restarted.email, 'user@example.com');
      await tap(tester, 'Выйти из аккаунта');
      expect(requests.last.path, '/auth/logout');
      expect(auth.isAuthorized, false);
      expect(preferences.authToken.get(), isNull);
      expect(preferences.authEmail.get(), isNull);
      expect(find.text('Гость'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('invalid email and delivery failure never open the code screen', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, 'Получить код');
    expect(requests, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('email_authorization_email')),
      'not-email',
    );
    await tap(tester, 'Получить код');
    expect(requests, isEmpty);
    status = 503;
    reply = (_) => {'error_code': 'EMAIL_DELIVERY_FAILED'};
    await requestCode(tester);
    expect(
      find.text('Не удалось отправить письмо. Попробуйте ещё раз позже.'),
      findsOneWidget,
    );
    expect(find.byType(EmailCodePage), findsNothing);
    expect(auth.isAuthorized, false);
    await unmount(tester);
  });

  testWidgets(
    'resend replaces challenge and rate limit blocks repeated verification',
    (tester) async {
      resendAfter = 0;
      await mount(tester);
      await requestCode(tester);
      await tap(tester, 'Отправить код снова');
      status = 400;
      reply = (_) => {'error_code': 'INVALID_EMAIL_CODE'};
      await tester.enterText(
        find.byKey(const ValueKey('email_authorization_code')),
        '123456',
      );
      await tester.pumpAndSettle();
      expect(requests.last.data['challenge_id'], 'challenge-2');
      expect(find.textContaining('Код неверный'), findsOneWidget);
      expect(auth.isAuthorized, false);
      status = 429;
      headers = {
        'retry-after': ['120'],
      };
      reply = (_) => {'error_code': 'EMAIL_CODE_RATE_LIMITED'};
      await tap(tester, 'Войти');
      final count = requests.length;
      expect(find.textContaining('Повторить через'), findsOneWidget);
      await tester.tap(find.textContaining('Повторить через'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests.length, count);
      await tester.enterText(
        find.byKey(const ValueKey('email_authorization_code')),
        '123457',
      );
      await tester.pumpAndSettle();
      expect(requests.length, count);
      await unmount(tester);
    },
  );

  testWidgets(
    'pending send disables double submission and late result after leaving is ignored',
    (tester) async {
      await mount(tester);
      pending = Completer<Object>();
      await tester.enterText(
        find.byKey(const ValueKey('email_authorization_email')),
        'user@example.com',
      );
      await tester.ensureVisible(find.text('Получить код'));
      await tester.tap(find.text('Получить код'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Отправляем…'), findsOneWidget);
      await tester.tap(find.text('Отправляем…'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests.length, 1);
      await unmount(tester);
      pending!.complete({
        'challenge_id': 'late',
        'expires_in': 300,
        'resend_after': 60,
      });
      await tester.pump();
      expect(find.byType(EmailCodePage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short code cannot submit; resend waits for the server interval',
    (tester) async {
      await mount(tester);
      await requestCode(tester);
      await tester.enterText(
        find.byKey(const ValueKey('email_authorization_code')),
        '12345',
      );
      await tap(tester, 'Войти');
      expect(find.text('Введите 6 цифр из письма'), findsOneWidget);
      expect(requests.length, 1);
      final resend = tester.widget<MonoTextButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is MonoTextButton &&
              widget.title.startsWith('Отправить снова через'),
        ),
      );
      expect(resend.onPressed, isNull);
      expect(requests.length, 1);
      await unmount(tester);
    },
  );

  testWidgets(
    'pasted PIN keeps leading zeros, filters text and clears on resend',
    (tester) async {
      resendAfter = 0;
      await mount(tester);
      await requestCode(tester);
      final successReply = reply;
      status = 400;
      reply = (_) => {'error_code': 'INVALID_EMAIL_CODE'};
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': '00 01 23x9'};
        }
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final editable = find.descendant(
        of: find.byKey(const ValueKey('email_authorization_code')),
        matching: find.byType(EditableText),
      );
      await tester
          .state<EditableTextState>(editable)
          .pasteText(SelectionChangedCause.toolbar);
      await tester.pumpAndSettle();
      final pin = tester.widget<MaterialPinFormField>(
        find.byType(MaterialPinFormField),
      );
      expect(pin.pinController!.text, '000123');
      expect(requests.last.data['code'], '000123');
      expect(requests.last.data['challenge_id'], 'challenge-1');
      status = 200;
      reply = successReply;
      await tap(tester, 'Отправить код снова');
      expect(pin.pinController!.text, isEmpty);
      pending = Completer<Object>();
      await tester.enterText(editable, '000123');
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests.last.data['code'], '000123');
      expect(requests.last.data['challenge_id'], 'challenge-2');
      final waiting = tester.widget<MaterialPinFormField>(
        find.byType(MaterialPinFormField),
      );
      expect(waiting.enabled, false);
      expect(waiting.readOnly, true);
      final count = requests.length;
      waiting.onSubmitted?.call('000123');
      await tester.pump();
      expect(requests.length, count);
      await unmount(tester);
      pending!.complete({
        'uuid': 'user-1',
        'email': 'user@example.com',
        'authToken': 'test-token',
        'isEmailVerified': true,
      });
      await tester.pump();
      expect(auth.isAuthorized, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'email and OTP remain usable on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, textScale: 2);
      await requestCode(tester);
      await tester.enterText(
        find.byKey(const ValueKey('email_authorization_code')),
        '000123',
      );
      await tester.pumpAndSettle();
      expect(auth.isAuthorized, true);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'last digit and corrected full code verify automatically without focus duplicates',
    (tester) async {
      await mount(tester);
      await requestCode(tester);
      final successReply = reply;
      status = 400;
      reply = (_) => {'error_code': 'INVALID_EMAIL_CODE'};
      final codeField = find.byKey(const ValueKey('email_authorization_code'));
      await tester.enterText(codeField, '12345');
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      await tester.enterText(codeField, '123456');
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests.last.data['code'], '123456');
      expect(find.textContaining('Код неверный'), findsOneWidget);
      final pin = tester.widget<MaterialPinFormField>(
        find.byType(MaterialPinFormField),
      );
      pin.pinController!.textController.selection =
          const TextSelection.collapsed(offset: 0);
      pin.pinController!.focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(find.textContaining('Код неверный'), findsOneWidget);
      status = 200;
      reply = successReply;
      await tester.enterText(codeField, '123457');
      await tester.pumpAndSettle();
      expect(requests.length, 3);
      expect(requests.last.data['code'], '123457');
      expect(auth.isAuthorized, true);
      await unmount(tester);
    },
  );
}
