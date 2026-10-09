// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleLoginRequest _$GoogleLoginRequestFromJson(Map<String, dynamic> json) =>
    GoogleLoginRequest(
      idToken: json['id_token'] as String,
      deviceInfo: json['device_info'] as String,
    );

Map<String, dynamic> _$GoogleLoginRequestToJson(GoogleLoginRequest instance) =>
    <String, dynamic>{
      'id_token': instance.idToken,
      'device_info': instance.deviceInfo,
    };
