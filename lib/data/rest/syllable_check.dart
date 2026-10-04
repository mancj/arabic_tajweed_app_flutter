import 'package:json_annotation/json_annotation.dart';

import 'letter_check.dart';

part 'syllable_check.g.dart';

enum SyllableCheckStatus { matched, mismatch, unclear }

/// Ответ POST /syllable. Огласовка оценивается отдельно от согласной;
/// unclear означает, что учебный ответ оценить нельзя.
@JsonSerializable(createToJson: false)
class SyllableCheck {
  const SyllableCheck({
    required this.expected,
    required this.heard,
    required this.status,
    required this.letterMatched,
    required this.harakaMatched,
    required this.hint,
    this.recording,
  });

  factory SyllableCheck.fromJson(Map<String, dynamic> json) =>
      _$SyllableCheckFromJson(json);

  @JsonKey(name: 'ожидалось', required: true)
  final String expected;

  @JsonKey(name: 'услышано', required: true)
  final String? heard;

  @JsonKey(name: 'статус', required: true)
  final SyllableCheckStatus status;

  @JsonKey(name: 'буква_совпала', required: true)
  final bool? letterMatched;

  @JsonKey(name: 'огласовка_совпала', required: true)
  final bool? harakaMatched;

  @JsonKey(name: 'подсказка', required: true)
  final String hint;

  @JsonKey(name: 'запись')
  final RecordingQuality? recording;

  bool get matched => status == SyllableCheckStatus.matched;
  bool get canEvaluate => status != SyllableCheckStatus.unclear;

  String get feedbackTitle => switch (status) {
    SyllableCheckStatus.matched => 'Слог прочитан правильно',
    SyllableCheckStatus.unclear => 'Не удалось уверенно разобрать слог',
    SyllableCheckStatus.mismatch => switch ((letterMatched, harakaMatched)) {
      (true, false) => 'Буква верная, огласовка отличается',
      (false, true) => 'Огласовка верная, буква отличается',
      _ => 'Буква и огласовка отличаются',
    },
  };

  /// Несогласованный ответ сервера нельзя превращать в учебный вердикт.
  void validateFor(String requested) {
    if (expected != requested || hint.trim().isEmpty) {
      throw const FormatException(
        'Ответ относится к другому слогу или неполон',
      );
    }
    final valid = switch (status) {
      SyllableCheckStatus.matched =>
        heard == expected && letterMatched == true && harakaMatched == true,
      SyllableCheckStatus.mismatch =>
        heard != null &&
            heard!.isNotEmpty &&
            heard != expected &&
            letterMatched != null &&
            harakaMatched != null &&
            (letterMatched == false || harakaMatched == false),
      SyllableCheckStatus.unclear =>
        letterMatched == null && harakaMatched == null,
    };
    if (!valid || (canEvaluate && recording?.warning != null)) {
      throw const FormatException('Противоречивый результат проверки слога');
    }
  }
}
