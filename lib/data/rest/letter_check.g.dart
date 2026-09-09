// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'letter_check.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LetterCheck _$LetterCheckFromJson(Map<String, dynamic> json) => LetterCheck(
  heard: json['услышано'] as String,
  hint: json['подсказка'] as String,
  score: (json['оценка'] as num).toInt(),
  nearest: (json['ближайшие'] as List<dynamic>)
      .map((e) => LetterGuess.fromJson(e as Map<String, dynamic>))
      .toList(),
  recording: RecordingQuality.fromJson(json['запись'] as Map<String, dynamic>),
  matched: json['совпало'] as bool? ?? false,
  expected: json['ожидалось'] as String?,
);

LetterGuess _$LetterGuessFromJson(Map<String, dynamic> json) => LetterGuess(
  letter: json['буква'] as String,
  similarity: (json['похожесть'] as num).toDouble(),
);

RecordingQuality _$RecordingQualityFromJson(Map<String, dynamic> json) =>
    RecordingQuality(
      speechFrom: (json['речь_с'] as num).toDouble(),
      loudnessDb: (json['громкость_дБ'] as num).toDouble(),
      clarityDb: (json['чистота_дБ'] as num).toDouble(),
      warning: json['предупреждение'] as String?,
    );
