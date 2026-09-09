import 'package:json_annotation/json_annotation.dart';

part 'letter_check.g.dart';

/// Ответ сервера на запись с названием буквы: `POST /letter?expected=ت`.
/// Ключи у сервера русские — как есть, чтобы не переводить туда-обратно.
@JsonSerializable(createToJson: false)
class LetterCheck {
  const LetterCheck({
    required this.heard,
    required this.hint,
    required this.score,
    required this.nearest,
    required this.recording,
    required this.matched,
    this.expected,
  });

  factory LetterCheck.fromJson(Map<String, dynamic> json) =>
      _$LetterCheckFromJson(json);

  /// Какую букву сервер услышал — сам глиф: «ط».
  @JsonKey(name: 'услышано')
  final String heard;

  /// Её имя словами: «то (толстая)».
  @JsonKey(name: 'подсказка')
  final String hint;

  /// Насколько запись похожа на ожидаемую букву, 0–100.
  @JsonKey(name: 'оценка')
  final int score;

  /// Ближайшие кандидаты по убыванию похожести.
  @JsonKey(name: 'ближайшие')
  final List<LetterGuess> nearest;

  @JsonKey(name: 'запись')
  final RecordingQuality recording;

  /// Что просили назвать. Пусто, если запрос был без `expected`.
  @JsonKey(name: 'ожидалось')
  final String? expected;

  /// Услышанное совпало с ожидаемым. Это и есть вердикт сервера.
  @JsonKey(name: 'совпало', defaultValue: false)
  final bool matched;
}

@JsonSerializable(createToJson: false)
class LetterGuess {
  const LetterGuess({required this.letter, required this.similarity});

  factory LetterGuess.fromJson(Map<String, dynamic> json) =>
      _$LetterGuessFromJson(json);

  @JsonKey(name: 'буква')
  final String letter;

  /// 0–1.
  @JsonKey(name: 'похожесть')
  final double similarity;
}

/// Что сервер думает о самой записи, отдельно от буквы.
@JsonSerializable(createToJson: false)
class RecordingQuality {
  const RecordingQuality({
    required this.speechFrom,
    required this.loudnessDb,
    required this.clarityDb,
    this.warning,
  });

  factory RecordingQuality.fromJson(Map<String, dynamic> json) =>
      _$RecordingQualityFromJson(json);

  /// С какой секунды в записи началась речь.
  @JsonKey(name: 'речь_с')
  final double speechFrom;

  @JsonKey(name: 'громкость_дБ')
  final double loudnessDb;

  /// Отношение речи к шуму.
  @JsonKey(name: 'чистота_дБ')
  final double clarityDb;

  /// «шумно», «тихо» и т.п. Есть — запись плохая, и несовпадение
  /// говорит о записи, а не о произношении.
  @JsonKey(name: 'предупреждение')
  final String? warning;
}
