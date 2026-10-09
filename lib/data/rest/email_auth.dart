import 'package:json_annotation/json_annotation.dart';

part 'email_auth.g.dart';

@JsonSerializable()
class RequestEmailCode {
  final String email;
  const RequestEmailCode({required this.email});
  factory RequestEmailCode.fromJson(Map<String, dynamic> json) =>
      _$RequestEmailCodeFromJson(json);
  Map<String, dynamic> toJson() => _$RequestEmailCodeToJson(this);
}

@JsonSerializable()
class EmailCodeChallenge {
  @JsonKey(name: 'challenge_id')
  final String challengeId;
  @JsonKey(name: 'expires_in')
  final int expiresIn;
  @JsonKey(name: 'resend_after')
  final int resendAfter;
  const EmailCodeChallenge({
    required this.challengeId,
    required this.expiresIn,
    required this.resendAfter,
  });
  factory EmailCodeChallenge.fromJson(Map<String, dynamic> json) =>
      _$EmailCodeChallengeFromJson(json);
  Map<String, dynamic> toJson() => _$EmailCodeChallengeToJson(this);
}

@JsonSerializable()
class VerifyEmailCode {
  @JsonKey(name: 'challenge_id')
  final String challengeId;
  final String code;
  @JsonKey(name: 'device_info')
  final String deviceInfo;
  const VerifyEmailCode({
    required this.challengeId,
    required this.code,
    required this.deviceInfo,
  });
  factory VerifyEmailCode.fromJson(Map<String, dynamic> json) =>
      _$VerifyEmailCodeFromJson(json);
  Map<String, dynamic> toJson() => _$VerifyEmailCodeToJson(this);
}

@JsonSerializable()
class EmailAuthSession {
  final String uuid;
  final String email;
  final String authToken;
  final bool isEmailVerified;
  const EmailAuthSession({
    required this.uuid,
    required this.email,
    required this.authToken,
    required this.isEmailVerified,
  });
  factory EmailAuthSession.fromJson(Map<String, dynamic> json) =>
      _$EmailAuthSessionFromJson(json);
  Map<String, dynamic> toJson() => _$EmailAuthSessionToJson(this);
}
