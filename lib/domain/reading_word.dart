import 'package:json_annotation/json_annotation.dart';

part 'reading_word.g.dart';

/// Одно слово общего банка. Подборки ссылаются на ID, а все упражнения
/// используют одинаковое написание, состав и запись целого слова.
@JsonSerializable()
class ReadingWord {
  const ReadingWord({
    required this.id,
    required this.display,
    required this.syllableIds,
    required this.audioFile,
    this.recorded = false,
    this.atomId,
  });

  factory ReadingWord.fromJson(Map<String, dynamic> json) =>
      _$ReadingWordFromJson(json);

  final String id;
  @JsonKey(name: 'joined')
  final String display;
  final List<String> syllableIds;
  final String audioFile;
  final bool recorded;
  @JsonKey(includeIfNull: false)
  final String? atomId;

  String get audioAsset => recorded ? audioFile : 'tts:$display';

  ReadingWord copyWith({bool? recorded}) => ReadingWord(
    id: id,
    display: display,
    syllableIds: syllableIds,
    audioFile: audioFile,
    recorded: recorded ?? this.recorded,
    atomId: atomId,
  );

  Map<String, dynamic> toJson() => _$ReadingWordToJson(this);
}
