import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:get/get.dart';

/// Кто сейчас вошёл в приложение. Пока хранит только токен:
/// его подставляет в заголовки [createApiClient], а сохраняется он
/// в настройках, чтобы пережить перезапуск.
class AuthState {
  final SharedPreferenceManager _prefs;
  final _authToken = RxnString();

  AuthState(this._prefs) {
    _authToken.value = _prefs.authToken.get();
  }

  String? get authToken => _authToken.value;

  bool get isAuthorized => authToken != null;

  /// Срабатывает при входе и выходе — удобно для перерисовки экранов.
  Stream<String?> get authTokenStream => _authToken.stream;

  Future<void> setAuthToken(String? token) async {
    _authToken.value = token;
    await _prefs.authToken.set(token);
  }
}
