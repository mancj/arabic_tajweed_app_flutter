import 'package:arabic_tajweed_app/app/shared_state/auth_state.dart';
import 'package:arabic_tajweed_app/data/rest/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Собирает единственный на всё приложение [Dio]: базовый адрес,
/// тайм-ауты и общие заголовки. Клиенты получают его через `Get.find<Dio>()`.
Dio createApiClient(AuthState authState) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(_CommonHeadersInterceptor(authState));

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (line) => debugPrint('[api] $line'),
      ),
    );
  }

  return dio;
}

/// Заголовки, которые нужны каждому запросу: токен пользователя,
/// платформа и язык устройства. Токен берётся при каждом запросе,
/// поэтому после входа или выхода ничего пересоздавать не нужно.
class _CommonHeadersInterceptor extends Interceptor {
  final AuthState _authState;

  _CommonHeadersInterceptor(this._authState);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _authState.authToken;
    if (token != null) {
      options.headers['x-auth-token'] = token;
    }

    final locale = PlatformDispatcher.instance.locale;
    options.headers['x-device-platform'] = defaultTargetPlatform.name;
    options.headers['x-device-lang-code'] = locale.languageCode;
    options.headers['x-device-locale'] = locale.toString();

    handler.next(options);
  }
}
