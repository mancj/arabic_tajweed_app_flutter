import 'package:json_annotation/json_annotation.dart';

part 'google_auth.g.dart';

@JsonSerializable()
class GoogleLoginRequest {
  @JsonKey(name: 'id_token')
  final String idToken;
  @JsonKey(name: 'device_info')
  final String deviceInfo;

  const GoogleLoginRequest({required this.idToken, required this.deviceInfo});

  factory GoogleLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$GoogleLoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$GoogleLoginRequestToJson(this);
}
