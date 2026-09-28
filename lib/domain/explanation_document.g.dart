// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explanation_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExplanationDocument _$ExplanationDocumentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationDocument', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['title', 'blocks']);
      final val = ExplanationDocument(
        title: $checkedConvert('title', (v) => v as String),
        blocks: $checkedConvert('blocks', (v) => _readBlocks(v as List)),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationDocumentToJson(
  ExplanationDocument instance,
) => <String, dynamic>{
  'title': instance.title,
  'blocks': _writeBlocks(instance.blocks),
};

ExplanationText _$ExplanationTextFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationText', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['text']);
      final val = ExplanationText($checkedConvert('text', (v) => v as String));
      return val;
    });

Map<String, dynamic> _$ExplanationTextToJson(ExplanationText instance) =>
    <String, dynamic>{'text': instance.text};

ExplanationLetter _$ExplanationLetterFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationLetter', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['letter']);
      final val = ExplanationLetter(
        $checkedConvert(
          'letter',
          (v) => ExplanationGlyph.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationLetterToJson(ExplanationLetter instance) =>
    <String, dynamic>{'letter': instance.letter.toJson()};

ExplanationMakhraj _$ExplanationMakhrajFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationMakhraj', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['makhraj']);
      final val = ExplanationMakhraj(
        $checkedConvert('makhraj', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationMakhrajToJson(ExplanationMakhraj instance) =>
    <String, dynamic>{'makhraj': instance.makhraj};

ExplanationSifat _$ExplanationSifatFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationSifat', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['sifat']);
      final val = ExplanationSifat(
        $checkedConvert('sifat', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationSifatToJson(ExplanationSifat instance) =>
    <String, dynamic>{'sifat': instance.sifat};

ExplanationForms _$ExplanationFormsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationForms', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['forms']);
      final val = ExplanationForms(
        $checkedConvert(
          'forms',
          (v) => (v as List<dynamic>)
              .map((e) => ExplanationForm.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationFormsToJson(ExplanationForms instance) =>
    <String, dynamic>{'forms': instance.forms.map((e) => e.toJson()).toList()};

ExplanationWord _$ExplanationWordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationWord', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['word']);
      final val = ExplanationWord(
        $checkedConvert(
          'word',
          (v) => ExplanationWordSample.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationWordToJson(ExplanationWord instance) =>
    <String, dynamic>{'word': instance.word.toJson()};

ExplanationExamples _$ExplanationExamplesFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationExamples', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['examples']);
      final val = ExplanationExamples(
        $checkedConvert(
          'examples',
          (v) => (v as List<dynamic>)
              .map((e) => ExplanationGlyph.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationExamplesToJson(
  ExplanationExamples instance,
) => <String, dynamic>{
  'examples': instance.examples.map((e) => e.toJson()).toList(),
};

ExplanationSound _$ExplanationSoundFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationSound', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['sound']);
      final val = ExplanationSound(
        $checkedConvert(
          'sound',
          (v) => ExplanationSoundData.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationSoundToJson(ExplanationSound instance) =>
    <String, dynamic>{'sound': instance.sound.toJson()};

ExplanationGlyph _$ExplanationGlyphFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationGlyph', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['glyph', 'audio', 'caption']);
      final val = ExplanationGlyph(
        glyph: $checkedConvert('glyph', (v) => v as String),
        audio: $checkedConvert('audio', (v) => v as String?),
        caption: $checkedConvert('caption', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationGlyphToJson(ExplanationGlyph instance) =>
    <String, dynamic>{
      'glyph': instance.glyph,
      'audio': instance.audio,
      'caption': instance.caption,
    };

ExplanationForm _$ExplanationFormFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExplanationForm', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['position', 'glyph', 'example']);
      final val = ExplanationForm(
        position: $checkedConvert(
          'position',
          (v) => $enumDecode(_$LetterFormEnumMap, v),
        ),
        glyph: $checkedConvert('glyph', (v) => v as String),
        example: $checkedConvert(
          'example',
          (v) => v == null
              ? null
              : ExplanationWordSample.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ExplanationFormToJson(ExplanationForm instance) =>
    <String, dynamic>{
      'position': _$LetterFormEnumMap[instance.position]!,
      'glyph': instance.glyph,
      'example': instance.example?.toJson(),
    };

const _$LetterFormEnumMap = {
  LetterForm.isolated: 'isolated',
  LetterForm.initial: 'initial',
  LetterForm.medial: 'medial',
  LetterForm.finalForm: 'finalForm',
};

ExplanationWordSample _$ExplanationWordSampleFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ExplanationWordSample', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['text', 'highlight', 'form']);
  final val = ExplanationWordSample(
    text: $checkedConvert('text', (v) => v as String),
    highlight: $checkedConvert('highlight', (v) => (v as num).toInt()),
    form: $checkedConvert(
      'form',
      (v) => $enumDecodeNullable(_$LetterFormEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$ExplanationWordSampleToJson(
  ExplanationWordSample instance,
) => <String, dynamic>{
  'text': instance.text,
  'highlight': instance.highlight,
  'form': _$LetterFormEnumMap[instance.form],
};

ExplanationSoundData _$ExplanationSoundDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ExplanationSoundData', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['label', 'audio']);
  final val = ExplanationSoundData(
    label: $checkedConvert('label', (v) => v as String),
    audio: $checkedConvert('audio', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$ExplanationSoundDataToJson(
  ExplanationSoundData instance,
) => <String, dynamic>{'label': instance.label, 'audio': instance.audio};
