import '../../../data/rest/api_exception.dart';

/// Переводит отказ сервера в действие, понятное человеку на экране входа.
String emailAuthErrorMessage(Object error) {
  if (error is ApiException) {
    return switch (error.errorCode) {
      'INVALID_EMAIL_CODE' =>
        'Код неверный или уже не действует. Проверьте письмо или запросите новый код.',
      'EMAIL_CODE_RATE_LIMITED' => 'Слишком много попыток. Попробуйте позже.',
      'EMAIL_DELIVERY_FAILED' =>
        'Не удалось отправить письмо. Попробуйте ещё раз позже.',
      'EMAIL_LOGIN_UNAVAILABLE' =>
        'Не удалось завершить вход. Запросите новый код.',
      _ => switch (error) {
        NoConnectionException() =>
          'Не удалось связаться с сервером. Проверьте подключение и попробуйте ещё раз.',
        ClientErrorException(statusCode: 429) =>
          'Слишком много попыток. Попробуйте позже.',
        ClientErrorException(statusCode: 400) => 'Проверьте введённые данные.',
        NotFoundException() => 'Вход по email недоступен на этом сервере.',
        _ => 'Не удалось выполнить запрос. Попробуйте ещё раз позже.',
      },
    };
  }
  return 'Не удалось завершить запрос. Попробуйте ещё раз.';
}
