// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestEmailCode _$RequestEmailCodeFromJson(Map<String, dynamic> json) =>
    RequestEmailCode(email: json['email'] as String);

Map<String, dynamic> _$RequestEmailCodeToJson(RequestEmailCode instance) =>
    <String, dynamic>{'email': instance.email};

EmailCodeChallenge _$EmailCodeChallengeFromJson(Map<String, dynamic> json) =>
    EmailCodeChallenge(
      challengeId: json['challenge_id'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      resendAfter: (json['resend_after'] as num).toInt(),
    );

Map<String, dynamic> _$EmailCodeChallengeToJson(EmailCodeChallenge instance) =>
    <String, dynamic>{
      'challenge_id': instance.challengeId,
      'expires_in': instance.expiresIn,
      'resend_after': instance.resendAfter,
    };

VerifyEmailCode _$VerifyEmailCodeFromJson(Map<String, dynamic> json) =>
    VerifyEmailCode(
      challengeId: json['challenge_id'] as String,
      code: json['code'] as String,
      deviceInfo: json['device_info'] as String,
    );

Map<String, dynamic> _$VerifyEmailCodeToJson(VerifyEmailCode instance) =>
    <String, dynamic>{
      'challenge_id': instance.challengeId,
      'code': instance.code,
      'device_info': instance.deviceInfo,
    };

EmailAuthSession _$EmailAuthSessionFromJson(Map<String, dynamic> json) =>
    EmailAuthSession(
      uuid: json['uuid'] as String,
      email: json['email'] as String,
      authToken: json['authToken'] as String,
      isEmailVerified: json['isEmailVerified'] as bool,
    );

Map<String, dynamic> _$EmailAuthSessionToJson(EmailAuthSession instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'email': instance.email,
      'authToken': instance.authToken,
      'isEmailVerified': instance.isEmailVerified,
    };
