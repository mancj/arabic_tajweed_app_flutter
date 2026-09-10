/// Адрес сервера и общие тайм-ауты. Отдельные запросы могут задать более
/// короткий предел через [Dio] options, если этого требует их сценарий.
class ApiConfig {
  /// Ходим на сервер, поднятый на машине разработчика. Не привязано
  /// к отладке нарочно: боевого сервера пока нет, а сборки из TestFlight
  /// релизные — с `kDebugMode` они уходили бы в пустоту. Когда сервер
  /// появится, выключить и заполнить боевой адрес ниже.
  static const bool _useLocalServer = true;

  /// Адрес этой машины в домашнем Wi-Fi по умолчанию: телефон и эмулятор
  /// ходят на него по сети, поэтому localhost здесь не годится. При смене
  /// сети адрес можно изменить на экране Debug.
  static const defaultBaseUrl = 'http://192.168.68.52:8765';

  static String get baseUrl {
    if (_useLocalServer) return defaultBaseUrl;
    // TODO: подставить адрес боевого сервера, когда он появится.
    return 'https://api.tajweed.app';
  }

  /// Приводит введённый адрес к виду, который принимает [Dio].
  /// Разрешаем вводить как полный URL, так и `IP:порт`.
  static String normalizeBaseUrl(String value) {
    final input = value.trim();
    if (input.isEmpty) throw const FormatException('Введите адрес сервера');

    final withScheme = input.contains('://') ? input : 'http://$input';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException('Используйте http:// или https://');
    }
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Укажите корректный адрес сервера');
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const FormatException('Нельзя указывать путь после адреса');
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw const FormatException('Адрес не должен содержать параметры');
    }

    return uri.replace(path: '', query: null, fragment: null).toString();
  }

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
