// Защищает обмен Google/Firebase на сессию нашего API: отмена, ошибка сервера
// и уход с экрана не должны авторизовать пользователя или сохранить чужой токен.
import 'dart:async';

import 'package:arabic_tajweed_app/app/pages/auth/authorization_page.dart';
import 'package:arabic_tajweed_app/app/pages/profile/profile_page.dart';
import 'package:arabic_tajweed_app/app/shared_state/auth_state.dart';
import 'package:arabic_tajweed_app/data/google_identity_provider.dart';
import 'package:arabic_tajweed_app/data/rest/auth_rest_client.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

class _GoogleIdentity extends GoogleIdentityProvider {
  Future<String?> Function() reply = () async => 'firebase-proof';
  int calls = 0;

  @override
  Future<String?> signIn() {
    calls++;
    return reply();
  }
}

void main() {
  late _GoogleIdentity google;
  late AuthState auth;
  late SharedPreferenceManager preferences;
  late Dio dio;
  late List<RequestOptions> requests;
  var status = 200;
  var verified = true;
  Completer<void>? serverWait;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    preferences = SharedPreferenceManager(
      await SharedPreferences.getInstance(),
    );
    auth = Get.put(AuthState(preferences));
    google = _GoogleIdentity();
    Get.put<GoogleIdentityProvider>(google);
    status = 200;
    verified = true;
    serverWait = null;
    requests = [];
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (serverWait != null) await serverWait!.future;
          final response = Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: status == 200
                ? {
                    'uuid': 'user-google',
                    'email': 'google@example.com',
                    'authToken': 'server-session',
                    'isEmailVerified': verified,
                  }
                : {'error_code': 'GOOGLE_AUTH_UNAVAILABLE'},
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

  tearDown(() {
    dio.close(force: true);
    Get.reset();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: ProfilePage.routeName,
        getPages: [
          GetPage(name: ProfilePage.routeName, page: () => const ProfilePage()),
          GetPage(
            name: AuthorizationPage.routeName,
            page: () => const AuthorizationPage(),
          ),
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Авторизация'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Войти с Google'));
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Войти с Google'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'server session is persisted, cancellation is silent and retry works',
    (tester) async {
      google.reply = () async => null;
      await mount(tester);
      await start(tester);
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(auth.isAuthorized, false);
      expect(find.textContaining('Не удалось'), findsNothing);
      google.reply = () async => 'firebase-proof';
      await start(tester);
      await tester.pumpAndSettle();
      expect(requests.single.path, '/auth/google');
      expect(requests.single.data['id_token'], 'firebase-proof');
      expect(requests.single.data['device_info'], isNotEmpty);
      expect(find.text('Вы вошли'), findsOneWidget);
      final restarted = AuthState(preferences);
      expect(restarted.authToken, 'server-session');
      expect(restarted.email, 'google@example.com');
      expect(preferences.authToken.get(), isNot('firebase-proof'));
    },
  );

  testWidgets(
    'server failure or unverified session never authorizes; retry succeeds',
    (tester) async {
      status = 503;
      await mount(tester);
      await start(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Вход с Google временно недоступен. Попробуйте позже.'),
        findsOneWidget,
      );
      expect(auth.isAuthorized, false);
      status = 200;
      verified = false;
      await tester.ensureVisible(find.text('Войти с Google'));
      await start(tester);
      await tester.pumpAndSettle();
      expect(auth.isAuthorized, false);
      expect(preferences.authToken.get(), isNull);
      verified = true;
      await tester.ensureVisible(find.text('Войти с Google'));
      await start(tester);
      await tester.pumpAndSettle();
      expect(auth.isAuthorized, true);
    },
  );

  testWidgets(
    'double tap is blocked; late native result after leaving is ignored',
    (tester) async {
      final nativeWait = Completer<String?>();
      google.reply = () => nativeWait.future;
      await mount(tester);
      await start(tester);
      expect(find.text('Входим…'), findsOneWidget);
      await tester.tap(find.text('Входим…'));
      await tester.pump();
      expect(google.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      nativeWait.complete('late-firebase-proof');
      await tester.pump();
      expect(requests, isEmpty);
      expect(auth.isAuthorized, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late backend session after leaving does not persist credentials',
    (tester) async {
      serverWait = Completer<void>();
      await mount(tester);
      await start(tester);
      expect(requests.length, 1);
      expect(auth.isAuthorized, false);
      await tester.pumpWidget(const SizedBox.shrink());
      serverWait!.complete();
      await tester.pump();
      await tester.pump();
      expect(auth.isAuthorized, false);
      expect(preferences.authToken.get(), isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
