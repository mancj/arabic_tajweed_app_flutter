// Защищает контракт с backend и скрытие кодов/токенов в сетевых логах.
import 'package:arabic_tajweed_app/app/shared_state/auth_state.dart';
import 'package:arabic_tajweed_app/data/rest/api_client.dart';
import 'package:arabic_tajweed_app/data/rest/api_exception.dart';
import 'package:arabic_tajweed_app/data/rest/auth_rest_client.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('OTP errors preserve server code and Retry-After', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 429,
                headers: Headers.fromMap({
                  'retry-after': ['90'],
                }),
                data: {'error_code': 'EMAIL_CODE_RATE_LIMITED'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      AuthRestClient(dio: dio).requestEmailCode('user@example.com'),
      throwsA(
        isA<ClientErrorException>()
            .having((e) => e.errorCode, 'error code', 'EMAIL_CODE_RATE_LIMITED')
            .having((e) => e.retryAfterSeconds, 'retry interval', 90),
      ),
    );
  });

  test(
    'authenticated requests carry token but logs contain no email, OTP or token',
    () async {
      SharedPreferences.setMockInitialValues({
        'authToken': 'private-test-token',
      });
      final preferences = SharedPreferenceManager(
        await SharedPreferences.getInstance(),
      );
      Get.put(preferences);
      addTearDown(Get.reset);
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = previous);
      final dio = createApiClient(AuthState(preferences));
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers['x-auth-token'], 'private-test-token');
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'uuid': 'u1',
                  'email': 'private@example.com',
                  'authToken': 'private-new-token',
                  'isEmailVerified': true,
                },
              ),
            );
          },
        ),
      );
      await AuthRestClient(
        dio: dio,
      ).verifyEmailCode(challengeId: 'test-id', code: '000123');
      await AuthRestClient(dio: dio).loginWithGoogle('private-firebase-proof');
      expect(logs, isNotEmpty);
      final output = logs.join('\n');
      for (final secret in [
        '000123',
        'private-test-token',
        'private-new-token',
        'private@example.com',
        'private-firebase-proof',
      ]) {
        expect(output, isNot(contains(secret)));
      }
    },
  );
}
