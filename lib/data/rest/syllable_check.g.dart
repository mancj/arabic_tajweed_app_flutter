// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'syllable_check.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyllableCheck _$SyllableCheckFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'ожидалось',
      'услышано',
      'статус',
      'буква_совпала',
      'огласовка_совпала',
      'подсказка',
    ],
  );
  return SyllableCheck(
    expected: json['ожидалось'] as String,
    heard: json['услышано'] as String?,
    status: $enumDecode(_$SyllableCheckStatusEnumMap, json['статус']),
    letterMatched: json['буква_совпала'] as bool?,
    harakaMatched: json['огласовка_совпала'] as bool?,
    hint: json['подсказка'] as String,
    recording: json['запись'] == null
        ? null
        : RecordingQuality.fromJson(json['запись'] as Map<String, dynamic>),
  );
}

const _$SyllableCheckStatusEnumMap = {
  SyllableCheckStatus.matched: 'matched',
  SyllableCheckStatus.mismatch: 'mismatch',
  SyllableCheckStatus.unclear: 'unclear',
};
