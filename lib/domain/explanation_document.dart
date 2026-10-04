import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

import 'atom.dart' show LetterForm;

part 'explanation_document.g.dart';

/// Содержимое одной карточки. Порядок блоков совпадает с порядком на экране.
@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationDocument {
  const ExplanationDocument({required this.title, required this.blocks});

  factory ExplanationDocument.fromJson(Map<String, dynamic> json) =>
      _$ExplanationDocumentFromJson(json);

  final String title;

  @JsonKey(fromJson: _readBlocks, toJson: _writeBlocks)
  final List<ExplanationBlock> blocks;

  Map<String, dynamic> toJson() => _$ExplanationDocumentToJson(this);
}

/// Новый тип добавляется сюда и в switch виджета ExplanationCard.
/// Поля каждого типа читает json_serializable; здесь выбирается только тип.
sealed class ExplanationBlock {
  const ExplanationBlock();

  Map<String, dynamic> toJson();

  static ExplanationBlock decode(Map<String, dynamic> json) {
    if (json.length != 1) {
      throw const FormatException('у блока должен быть ровно один тип');
    }
    return switch (json.keys.single) {
      'text' => ExplanationText.fromJson(json),
      'letter' => ExplanationLetter.fromJson(json),
      'writing' => ExplanationWriting.fromJson(json),
      'makhraj' => ExplanationMakhraj.fromJson(json),
      'sifat' => ExplanationSifat.fromJson(json),
      'forms' => ExplanationForms.fromJson(json),
      'word' => ExplanationWord.fromJson(json),
      'examples' => ExplanationExamples.fromJson(json),
      'sound' => ExplanationSound.fromJson(json),
      final key => throw FormatException('неизвестный тип блока "$key"'),
    };
  }
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationText extends ExplanationBlock {
  const ExplanationText(this.text);
  factory ExplanationText.fromJson(Map<String, dynamic> json) =>
      _$ExplanationTextFromJson(json);
  final String text;
  @override
  Map<String, dynamic> toJson() => _$ExplanationTextToJson(this);
}

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
)
class ExplanationLetter extends ExplanationBlock {
  const ExplanationLetter(this.letter);
  factory ExplanationLetter.fromJson(Map<String, dynamic> json) =>
      _$ExplanationLetterFromJson(json);

  /// Начертание и необязательная запись живут внутри карточки.
  final ExplanationGlyph letter;
  @override
  Map<String, dynamic> toJson() => _$ExplanationLetterToJson(this);
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationWriting extends ExplanationBlock {
  const ExplanationWriting(this.writing);
  factory ExplanationWriting.fromJson(Map<String, dynamic> json) =>
      _$ExplanationWritingFromJson(json);

  final String writing;
  @override
  Map<String, dynamic> toJson() => _$ExplanationWritingToJson(this);
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationMakhraj extends ExplanationBlock {
  const ExplanationMakhraj(this.makhraj);
  factory ExplanationMakhraj.fromJson(Map<String, dynamic> json) =>
      _$ExplanationMakhrajFromJson(json);

  final String makhraj;
  @override
  Map<String, dynamic> toJson() => _$ExplanationMakhrajToJson(this);
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationSifat extends ExplanationBlock {
  const ExplanationSifat(this.sifat);
  factory ExplanationSifat.fromJson(Map<String, dynamic> json) =>
      _$ExplanationSifatFromJson(json);

  final String sifat;
  @override
  Map<String, dynamic> toJson() => _$ExplanationSifatToJson(this);
}

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
)
class ExplanationForms extends ExplanationBlock {
  const ExplanationForms(this.forms);
  factory ExplanationForms.fromJson(Map<String, dynamic> json) =>
      _$ExplanationFormsFromJson(json);

  /// Начертания и примеры каждой формы живут внутри карточки.
  final List<ExplanationForm> forms;
  @override
  Map<String, dynamic> toJson() => _$ExplanationFormsToJson(this);
}

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
)
class ExplanationWord extends ExplanationBlock {
  const ExplanationWord(this.word);
  factory ExplanationWord.fromJson(Map<String, dynamic> json) =>
      _$ExplanationWordFromJson(json);

  final ExplanationWordSample word;
  @override
  Map<String, dynamic> toJson() => _$ExplanationWordToJson(this);
}

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
)
class ExplanationExamples extends ExplanationBlock {
  const ExplanationExamples(this.examples);
  factory ExplanationExamples.fromJson(Map<String, dynamic> json) =>
      _$ExplanationExamplesFromJson(json);
  final List<ExplanationGlyph> examples;
  @override
  Map<String, dynamic> toJson() => _$ExplanationExamplesToJson(this);
}

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
)
class ExplanationSound extends ExplanationBlock {
  const ExplanationSound(this.sound);
  factory ExplanationSound.fromJson(Map<String, dynamic> json) =>
      _$ExplanationSoundFromJson(json);
  final ExplanationSoundData sound;
  @override
  Map<String, dynamic> toJson() => _$ExplanationSoundToJson(this);
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationGlyph {
  const ExplanationGlyph({required this.glyph, this.audio, this.caption});
  factory ExplanationGlyph.fromJson(Map<String, dynamic> json) =>
      _$ExplanationGlyphFromJson(json);

  final String glyph;

  /// Путь для плеера без начального assets/: audio/alphabet/ba.wav.
  final String? audio;
  final String? caption;

  Map<String, dynamic> toJson() => _$ExplanationGlyphToJson(this);
}

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
)
class ExplanationForm {
  const ExplanationForm({
    required this.position,
    required this.glyph,
    this.example,
  });
  factory ExplanationForm.fromJson(Map<String, dynamic> json) =>
      _$ExplanationFormFromJson(json);

  final LetterForm position;
  final String glyph;
  final ExplanationWordSample? example;

  Map<String, dynamic> toJson() => _$ExplanationFormToJson(this);
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationWordSample {
  const ExplanationWordSample({
    required this.text,
    required this.highlight,
    this.form,
  });
  factory ExplanationWordSample.fromJson(Map<String, dynamic> json) =>
      _$ExplanationWordSampleFromJson(json);

  final String text;
  final int highlight;
  final LetterForm? form;

  Map<String, dynamic> toJson() => _$ExplanationWordSampleToJson(this);
}

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class ExplanationSoundData {
  const ExplanationSoundData({required this.label, required this.audio});
  factory ExplanationSoundData.fromJson(Map<String, dynamic> json) =>
      _$ExplanationSoundDataFromJson(json);

  final String label;
  final String audio;

  Map<String, dynamic> toJson() => _$ExplanationSoundDataToJson(this);
}

List<ExplanationBlock> _readBlocks(List<dynamic> values) => List.unmodifiable(
  values.mapIndexed((index, value) {
    try {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('ожидается описание блока');
      }
      return ExplanationBlock.decode(value);
    } catch (error) {
      throw FormatException('blocks[$index]: $error');
    }
  }),
);

List<Map<String, dynamic>> _writeBlocks(List<ExplanationBlock> blocks) =>
    blocks.map((block) => block.toJson()).toList();

/// Проверенная карточка. Иллюстрации в ней не являются атомами курса.
class ExplanationContent {
  ExplanationContent({required this.document}) {
    if (document.title.trim().isEmpty || document.blocks.isEmpty) {
      throw const FormatException('нужны заголовок и хотя бы один блок');
    }
    for (final (index, block) in document.blocks.indexed) {
      try {
        switch (block) {
          case ExplanationText(:final text):
            if (text.trim().isEmpty) {
              throw const FormatException('текст не должен быть пустым');
            }
          case ExplanationMakhraj(:final makhraj):
            if (makhraj.trim().isEmpty) {
              throw const FormatException(
                'описание махраджа не должно быть пустым',
              );
            }
          case ExplanationWriting(:final writing):
            if (writing.trim().isEmpty) {
              throw const FormatException(
                'описание написания не должно быть пустым',
              );
            }
          case ExplanationSifat(:final sifat):
            if (sifat.trim().isEmpty) {
              throw const FormatException(
                'описание сыфата не должно быть пустым',
              );
            }
          case ExplanationLetter(:final letter):
            _validateGlyph(letter);
          case ExplanationForms(:final forms):
            if (forms.isEmpty) {
              throw const FormatException('список форм пуст');
            }
            final seen = <LetterForm>{};
            for (final (formIndex, form) in forms.indexed) {
              if (!seen.add(form.position)) {
                throw FormatException('forms[$formIndex]: форма повторяется');
              }
              if (form.glyph.trim().isEmpty) {
                throw FormatException('forms[$formIndex]: начертание пусто');
              }
              if (form.example case final example?) {
                try {
                  _validateWord(example);
                } on FormatException catch (error) {
                  throw FormatException('forms[$formIndex]: ${error.message}');
                }
              }
            }
          case ExplanationWord(:final word):
            _validateWord(word);
          case ExplanationExamples(:final examples):
            if (examples.isEmpty) {
              throw const FormatException('список примеров пуст');
            }
            for (final (exampleIndex, example) in examples.indexed) {
              try {
                _validateGlyph(example);
              } on FormatException catch (error) {
                throw FormatException(
                  'examples[$exampleIndex]: ${error.message}',
                );
              }
            }
          case ExplanationSound(:final sound):
            if (sound.label.trim().isEmpty) {
              throw const FormatException('подпись звука пуста');
            }
            _validateAudio(sound.audio);
        }
      } on FormatException catch (error) {
        throw FormatException('blocks[$index]: ${error.message}');
      }
    }
  }

  final ExplanationDocument document;

  static void _validateGlyph(ExplanationGlyph value) {
    if (value.glyph.trim().isEmpty) {
      throw const FormatException('начертание пусто');
    }
    if (value.caption != null && value.caption!.trim().isEmpty) {
      throw const FormatException('подпись пуста');
    }
    if (value.audio case final audio?) _validateAudio(audio);
  }

  static void _validateWord(ExplanationWordSample value) {
    if (value.text.trim().isEmpty ||
        value.highlight < 0 ||
        value.highlight >= value.text.length) {
      throw const FormatException('слово или позиция подсветки некорректны');
    }
  }

  static void _validateAudio(String asset) {
    if ((!asset.startsWith('audio/') && !asset.startsWith('tts:')) ||
        asset.contains('..') ||
        asset == 'tts:') {
      throw FormatException('неверный путь к звуку "$asset"');
    }
  }
}
