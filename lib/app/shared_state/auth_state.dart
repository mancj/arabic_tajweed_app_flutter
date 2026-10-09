import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/data/rest/email_auth.dart';
import 'package:get/get.dart';

/// Токен и email текущей сессии сохраняются в настройках между запусками.
/// Токен подставляется в заголовки запросов к API.
class AuthState {
  final SharedPreferenceManager _prefs;
  final _authToken = RxnString();
  String? _email;

  AuthState(this._prefs) {
    _authToken.value = _prefs.authToken.get();
    _email = _prefs.authEmail.get();
  }

  String? get authToken => _authToken.value;

  bool get isAuthorized => authToken != null;
  String? get email => _email;

  /// Срабатывает при входе и выходе — удобно для перерисовки экранов.
  Stream<String?> get authTokenStream => _authToken.stream;

  Future<void> setAuthToken(String? token) async {
    if (token == null) {
      await _prefs.authEmail.set(null);
      _email = null;
    }
    await _prefs.authToken.set(token);
    _authToken.value = token;
  }

  Future<void> setSession(EmailAuthSession session) async {
    if (session.authToken.isEmpty || !session.isEmailVerified) {
      throw const FormatException('Некорректная сессия');
    }
    await _prefs.authEmail.set(session.email);
    _email = session.email;
    await setAuthToken(session.authToken);
  }
}
