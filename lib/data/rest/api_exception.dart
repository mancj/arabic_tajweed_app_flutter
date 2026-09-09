import 'package:dio/dio.dart';

/// Ошибки сети, понятные остальному приложению.
///
/// Перечень закрыт (sealed): `switch` по ним обязан разобрать все случаи,
/// и при появлении нового вида ошибки компилятор покажет, где его забыли.
/// Клиенты не пробрасывают `DioException` наружу — только эти классы.
sealed class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  /// Переводит ошибку Dio в одну из наших.
  factory ApiException.fromDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => NoConnectionException(
        e.message ?? 'Нет соединения',
      ),
      DioExceptionType.cancel => const RequestCancelledException(),
      _ => switch (e.response?.statusCode) {
        401 => const UnauthorizedException(),
        404 => const NotFoundException(),
        final int status when status >= 500 => ServerException(
          status,
          _bodyMessage(e),
        ),
        final int status => ClientErrorException(status, _bodyMessage(e)),
        null => UnknownApiException(e.message ?? e.toString()),
      },
    };
  }

  /// Достаёт текст ошибки из тела ответа, если сервер его прислал.
  static String _bodyMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final text =
          data['message'] ?? data['error'] ?? data['detail'] ?? data['ошибка'];
      if (text is String && text.isNotEmpty) return text;
    }
    return e.response?.statusMessage ?? e.message ?? 'Ошибка сервера';
  }

  @override
  String toString() => '$runtimeType: $message';
}

/// Нет сети или сервер не ответил вовремя.
class NoConnectionException extends ApiException {
  const NoConnectionException(super.message);
}

/// Запрос отменили сами (например, ушли со страницы).
class RequestCancelledException extends ApiException {
  const RequestCancelledException() : super('Запрос отменён');
}

/// 401 — токен протух или его нет. Обычно значит «разлогинить».
class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('Нужна авторизация');
}

/// 404 — такого ресурса нет.
class NotFoundException extends ApiException {
  const NotFoundException() : super('Не найдено');
}

/// Остальные 4xx — сервер отверг запрос (плохие данные, нет прав и т.п.).
class ClientErrorException extends ApiException {
  final int statusCode;

  const ClientErrorException(this.statusCode, super.message);
}

/// 5xx — сервер сломался.
class ServerException extends ApiException {
  final int statusCode;

  const ServerException(this.statusCode, super.message);
}

/// Всё, что не подошло ни под один случай выше.
class UnknownApiException extends ApiException {
  const UnknownApiException(super.message);
}
