// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pronunciation_check.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PronunciationTarget _$PronunciationTargetFromJson(Map<String, dynamic> json) =>
    PronunciationTarget(
      type: json['type'] as String,
      id: json['id'] as String,
      expected: json['expected'] as String,
    );

Map<String, dynamic> _$PronunciationTargetToJson(
  PronunciationTarget instance,
) => <String, dynamic>{
  'type': instance.type,
  'id': instance.id,
  'expected': instance.expected,
};

PronunciationCheck _$PronunciationCheckFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['heard', 'recording']);
  return PronunciationCheck(
    version: (json['version'] as num).toInt(),
    target: PronunciationTarget.fromJson(
      json['target'] as Map<String, dynamic>,
    ),
    status: $enumDecode(_$PronunciationStatusEnumMap, json['status']),
    heard: json['heard'] as String?,
    rawHeard: json['rawHeard'] as String?,
    hint: json['hint'] as String,
    checks: (json['checks'] as List<dynamic>)
        .map(
          (e) =>
              PronunciationComponentCheck.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    recording: json['recording'] == null
        ? null
        : RecordingQuality.fromJson(json['recording'] as Map<String, dynamic>),
    isStub: json['isStub'] as bool,
  );
}

const _$PronunciationStatusEnumMap = {
  PronunciationStatus.matched: 'matched',
  PronunciationStatus.mismatch: 'mismatch',
  PronunciationStatus.unclear: 'unclear',
};

PronunciationComponentCheck _$PronunciationComponentCheckFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(json, requiredKeys: const ['matched']);
  return PronunciationComponentCheck(
    code: json['code'] as String,
    matched: json['matched'] as bool?,
  );
}

RecordingQuality _$RecordingQualityFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['warning']);
  return RecordingQuality(
    speechFrom: (json['speechFrom'] as num).toDouble(),
    loudnessDb: (json['loudnessDb'] as num).toDouble(),
    clarityDb: (json['clarityDb'] as num).toDouble(),
    warning: json['warning'] as String?,
  );
}
