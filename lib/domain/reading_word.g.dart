// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_word.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadingWord _$ReadingWordFromJson(Map<String, dynamic> json) => ReadingWord(
  id: json['id'] as String,
  display: json['joined'] as String,
  syllableIds: (json['syllableIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  audioFile: json['audioFile'] as String,
  recorded: json['recorded'] as bool? ?? false,
  atomId: json['atomId'] as String?,
);

Map<String, dynamic> _$ReadingWordToJson(ReadingWord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'joined': instance.display,
      'syllableIds': instance.syllableIds,
      'audioFile': instance.audioFile,
      'recorded': instance.recorded,
      'atomId': ?instance.atomId,
    };
