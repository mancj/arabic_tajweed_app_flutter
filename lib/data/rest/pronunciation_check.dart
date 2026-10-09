import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pronunciation_check.g.dart';

/// Тип — строка: новые учебные единицы не требуют другого формата API.
abstract final class PronunciationUnitType {
  static const letter = 'letter';
  static const syllable = 'vocalized_syllable';
  static const word = 'short_word';
}

enum PronunciationStatus { matched, mismatch, unclear }

@JsonSerializable()
class PronunciationTarget {
  const PronunciationTarget({
    required this.type,
    required this.id,
    required this.expected,
  });
  factory PronunciationTarget.fromJson(Map<String, dynamic> json) =>
      _$PronunciationTargetFromJson(json);
  Map<String, dynamic> toJson() => _$PronunciationTargetToJson(this);
  final String type;
  final String id;
  final String expected;
}

/// Один ответ для букв, слогов, слов и будущих правил чтения.
@JsonSerializable(createToJson: false)
class PronunciationCheck {
  const PronunciationCheck({
    required this.version,
    required this.target,
    required this.status,
    required this.heard,
    this.rawHeard,
    required this.hint,
    required this.checks,
    required this.recording,
    required this.isStub,
  });
  factory PronunciationCheck.fromJson(Map<String, dynamic> json) =>
      _$PronunciationCheckFromJson(json);
  final int version;
  final PronunciationTarget target;
  final PronunciationStatus status;
  @JsonKey(required: true)
  final String? heard;

  /// Исходный текст модели; старые серверы могут его не присылать.
  final String? rawHeard;
  final String hint;
  final List<PronunciationComponentCheck> checks;
  @JsonKey(required: true)
  final RecordingQuality? recording;
  final bool isStub;

  bool get matched => status == PronunciationStatus.matched;
  bool get canEvaluate => status != PronunciationStatus.unclear;
  bool? get letterMatched => _component('letter');
  bool? get harakaMatched => _component('haraka');
  bool? _component(String code) =>
      checks.firstWhereOrNull((check) => check.code == code)?.matched;

  String get feedbackTitle {
    final unit = switch (target.type) {
      PronunciationUnitType.syllable => 'слог',
      PronunciationUnitType.word => 'слово',
      _ => 'произношение',
    };
    if (isStub) return 'Запись принята';
    if (status == PronunciationStatus.unclear) {
      return 'Не удалось уверенно разобрать $unit';
    }
    if (matched) {
      return switch (target.type) {
        PronunciationUnitType.syllable => 'Слог прочитан правильно',
        PronunciationUnitType.word => 'Слово прочитано правильно',
        _ => 'Правильно произнесено',
      };
    }
    if (target.type == PronunciationUnitType.syllable) {
      return switch ((letterMatched, harakaMatched)) {
        (true, false) => 'Буква верная, огласовка отличается',
        (false, true) => 'Огласовка верная, буква отличается',
        _ => 'Буква и огласовка отличаются',
      };
    }
    return 'Попробуйте ещё раз';
  }

  /// Чужой или противоречивый ответ — ошибка сервиса, без учебной оценки.
  void validateFor(PronunciationTarget requested) {
    if (version != 1 ||
        target.type != requested.type ||
        target.id != requested.id ||
        target.expected != requested.expected ||
        hint.trim().isEmpty ||
        checks.map((check) => check.code).toSet().length != checks.length ||
        checks.any((check) => check.code.trim().isEmpty)) {
      throw const FormatException('Неполный ответ или другая учебная единица');
    }
    final valid = isStub
        ? matched && heard == null && checks.isEmpty && recording == null
        : switch (status) {
            PronunciationStatus.matched =>
              heard == target.expected &&
                  checks.every((check) => check.matched == true),
            PronunciationStatus.mismatch =>
              heard != null &&
                  heard!.trim().isNotEmpty &&
                  heard != target.expected &&
                  checks.every((check) => check.matched != null) &&
                  (checks.isEmpty ||
                      checks.any((check) => check.matched == false)),
            PronunciationStatus.unclear => checks.every(
              (check) => check.matched == null,
            ),
          };
    final completeSyllable =
        isStub ||
        !canEvaluate ||
        target.type != PronunciationUnitType.syllable ||
        (letterMatched != null && harakaMatched != null);
    if (!valid ||
        !completeSyllable ||
        (canEvaluate && recording?.warning != null)) {
      throw const FormatException('Противоречивый результат проверки');
    }
  }
}

@JsonSerializable(createToJson: false)
class PronunciationComponentCheck {
  const PronunciationComponentCheck({
    required this.code,
    required this.matched,
  });
  factory PronunciationComponentCheck.fromJson(Map<String, dynamic> json) =>
      _$PronunciationComponentCheckFromJson(json);
  final String code;
  @JsonKey(required: true)
  final bool? matched;
}

@JsonSerializable(createToJson: false)
class RecordingQuality {
  const RecordingQuality({
    required this.speechFrom,
    required this.loudnessDb,
    required this.clarityDb,
    required this.warning,
  });
  factory RecordingQuality.fromJson(Map<String, dynamic> json) =>
      _$RecordingQualityFromJson(json);
  final double speechFrom;
  final double loudnessDb;
  final double clarityDb;
  @JsonKey(required: true)
  final String? warning;
}
