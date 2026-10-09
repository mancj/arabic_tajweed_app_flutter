import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Возвращает доказательство входа для backend, null при отмене пользователем.
abstract class GoogleIdentityProvider {
  Future<String?> signIn();
}

class FirebaseGoogleIdentityProvider implements GoogleIdentityProvider {
  Future<void>? _initialization;

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await GoogleSignIn.instance.initialize();
  }

  @override
  Future<String?> signIn() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      throw UnsupportedError('Google sign-in requires the mobile app');
    }
    try {
      await (_initialization ??= _initialize());
    } catch (_) {
      _initialization = null;
      rethrow;
    }

    final google = GoogleSignIn.instance;
    final firebase = FirebaseAuth.instance;
    // После выхода из аккаунта снова предлагаем выбор пользователя.
    await google.signOut();
    try {
      final account = await google.authenticate();
      final googleToken = account.authentication.idToken;
      if (googleToken == null || googleToken.isEmpty) {
        throw const FormatException('Missing Google ID token');
      }
      final result = await firebase.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleToken),
      );
      // Backend проверяет Firebase ID token, а не исходный Google ID token.
      final firebaseToken = await result.user?.getIdToken(true);
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw const FormatException('Missing Firebase ID token');
      }
      return firebaseToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    } finally {
      // В приложении хранится только сессия нашего API; Firebase нужен для обмена.
      await firebase.signOut();
    }
  }
}
