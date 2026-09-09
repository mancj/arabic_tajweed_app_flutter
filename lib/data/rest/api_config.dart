/// Адрес сервера и общие тайм-ауты. Отдельные запросы могут задать более
/// короткий предел через [Dio] options, если этого требует их сценарий.
class ApiConfig {
  /// Ходим на сервер, поднятый на машине разработчика. Не привязано
  /// к отладке нарочно: боевого сервера пока нет, а сборки из TestFlight
  /// релизные — с `kDebugMode` они уходили бы в пустоту. Когда сервер
  /// появится, выключить и заполнить боевой адрес ниже.
  static const bool _useLocalServer = true;

  /// Адрес этой машины в домашнем Wi-Fi: телефон и эмулятор ходят
  /// на него по сети, поэтому localhost здесь не годится. Сменился
  /// роутер или сеть — поправить здесь (`ipconfig getifaddr en0`).
  static const _localServer = 'http://192.168.68.53:8765';

  static String get baseUrl {
    if (_useLocalServer) return _localServer;
    // TODO: подставить адрес боевого сервера, когда он появится.
    return 'https://api.tajweed.app';
  }

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
