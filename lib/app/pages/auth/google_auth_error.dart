import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/rest/api_exception.dart';

String googleAuthErrorMessage(Object error) {
  if (error is UnsupportedError) {
    return 'Вход с Google доступен в приложении для iOS и Android.';
  }
  if (error is FirebaseAuthException &&
          error.code == 'network-request-failed' ||
      error is NoConnectionException) {
    return 'Не удалось связаться с сервером. Проверьте подключение и попробуйте ещё раз.';
  }
  if (error is ApiException) {
    return switch (error.errorCode) {
      'AUTH_ACCOUNT_DELETED' => 'Этот аккаунт удалён. Обратитесь в поддержку.',
      'AUTH_ACCOUNT_CONFLICT' =>
        'Не удалось связать аккаунт. Обратитесь в поддержку.',
      'GOOGLE_AUTH_NOT_CONFIGURED' || 'GOOGLE_AUTH_UNAVAILABLE' =>
        'Вход с Google временно недоступен. Попробуйте позже.',
      _ => switch (error) {
        UnauthorizedException() =>
          'Не удалось подтвердить вход. Выберите аккаунт Google ещё раз.',
        ClientErrorException(statusCode: 429) =>
          'Слишком много попыток. Попробуйте позже.',
        _ => 'Не удалось войти с Google. Попробуйте ещё раз позже.',
      },
    };
  }
  return 'Не удалось войти с Google. Попробуйте ещё раз.';
}
