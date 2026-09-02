// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'atom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Atom _$AtomFromJson(Map<String, dynamic> json) => Atom(
  id: json['id'] as String,
  kind: $enumDecode(_$AtomKindEnumMap, json['kind']),
  display: json['display'] as String,
  label: json['label'] as String? ?? '',
  note: json['note'] as String? ?? '',
  letterId: json['letterId'] as String?,
  form: $enumDecodeNullable(_$LetterFormEnumMap, json['form']),
  confusableWith:
      (json['confusableWith'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$AtomToJson(Atom instance) => <String, dynamic>{
  'id': instance.id,
  'kind': _$AtomKindEnumMap[instance.kind]!,
  'display': instance.display,
  'label': instance.label,
  'note': instance.note,
  'letterId': instance.letterId,
  'form': _$LetterFormEnumMap[instance.form],
  'confusableWith': instance.confusableWith,
};

const _$AtomKindEnumMap = {
  AtomKind.letterForm: 'letterForm',
  AtomKind.haraka: 'haraka',
  AtomKind.sign: 'sign',
  AtomKind.syllable: 'syllable',
  AtomKind.concept: 'concept',
};

const _$LetterFormEnumMap = {
  LetterForm.isolated: 'isolated',
  LetterForm.initial: 'initial',
  LetterForm.medial: 'medial',
  LetterForm.finalForm: 'finalForm',
};
