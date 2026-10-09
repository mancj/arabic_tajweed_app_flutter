import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'email_auth.dart';
import 'google_auth.dart';
import 'rest_client.dart';

/// Вход по email или Google и выход из текущей серверной сессии.
class AuthRestClient extends RestClient {
  AuthRestClient({super.dio});

  Future<EmailCodeChallenge> requestEmailCode(
    String email, {
    CancelToken? cancelToken,
  }) => postObject(
    '/auth/email/request-code',
    EmailCodeChallenge.fromJson,
    data: RequestEmailCode(email: email).toJson(),
    cancelToken: cancelToken,
  );

  Future<EmailAuthSession> verifyEmailCode({
    required String challengeId,
    required String code,
    CancelToken? cancelToken,
  }) => postObject(
    '/auth/email/verify-code',
    EmailAuthSession.fromJson,
    data: VerifyEmailCode(
      challengeId: challengeId,
      code: code,
      deviceInfo: defaultTargetPlatform.name,
    ).toJson(),
    cancelToken: cancelToken,
  );

  Future<EmailAuthSession> loginWithGoogle(
    String firebaseIdToken, {
    CancelToken? cancelToken,
  }) => postObject(
    '/auth/google',
    EmailAuthSession.fromJson,
    data: GoogleLoginRequest(
      idToken: firebaseIdToken,
      deviceInfo: defaultTargetPlatform.name,
    ).toJson(),
    cancelToken: cancelToken,
  );

  Future<void> logout() => post('/auth/logout');
}
