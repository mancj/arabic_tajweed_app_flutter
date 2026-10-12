// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PracticeProfile _$PracticeProfileFromJson(Map<String, dynamic> json) =>
    PracticeProfile(
      approach:
          $enumDecodeNullable(_$PracticeApproachEnumMap, json['approach']) ??
          PracticeApproach.configured,
      plannedExercises: (json['plannedExercises'] as num?)?.toInt() ?? 2,
      maxExercisesPerSession:
          (json['maxExercisesPerSession'] as num?)?.toInt() ?? 3,
      maxAtomsPerSession: (json['maxAtomsPerSession'] as num?)?.toInt() ?? 8,
      initialModes:
          (json['initialModes'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$ExerciseModeEnumMap, e))
              .toList() ??
          const [],
      reviewModes:
          (json['reviewModes'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$ExerciseModeEnumMap, e))
              .toList() ??
          const [],
      requiredModes:
          (json['requiredModes'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$ExerciseModeEnumMap, e))
              .toList() ??
          const [],
      pronunciationMode: $enumDecodeNullable(
        _$ExerciseModeEnumMap,
        json['pronunciationMode'],
      ),
      pronunciationMaxPercent:
          (json['pronunciationMaxPercent'] as num?)?.toInt() ?? 15,
      preferSameLetters: json['preferSameLetters'] as bool? ?? false,
      reviewLessonMinExercises: (json['reviewLessonMinExercises'] as num?)
          ?.toInt(),
    );

Map<String, dynamic> _$PracticeProfileToJson(PracticeProfile instance) =>
    <String, dynamic>{
      'approach': _$PracticeApproachEnumMap[instance.approach]!,
      'plannedExercises': instance.plannedExercises,
      'maxExercisesPerSession': instance.maxExercisesPerSession,
      'maxAtomsPerSession': instance.maxAtomsPerSession,
      'initialModes': instance.initialModes
          .map((e) => _$ExerciseModeEnumMap[e]!)
          .toList(),
      'reviewModes': instance.reviewModes
          .map((e) => _$ExerciseModeEnumMap[e]!)
          .toList(),
      'requiredModes': instance.requiredModes
          .map((e) => _$ExerciseModeEnumMap[e]!)
          .toList(),
      'pronunciationMode': _$ExerciseModeEnumMap[instance.pronunciationMode],
      'pronunciationMaxPercent': instance.pronunciationMaxPercent,
      'preferSameLetters': instance.preferSameLetters,
      'reviewLessonMinExercises': instance.reviewLessonMinExercises,
    };

const _$PracticeApproachEnumMap = {
  PracticeApproach.standard: 'standard',
  PracticeApproach.configured: 'configured',
};

const _$ExerciseModeEnumMap = {
  ExerciseMode.formToName: 'formToName',
  ExerciseMode.nameToForm: 'nameToForm',
  ExerciseMode.findInWord: 'findInWord',
  ExerciseMode.distinguishDots: 'distinguishDots',
  ExerciseMode.formToPosition: 'formToPosition',
  ExerciseMode.soundToLetter: 'soundToLetter',
  ExerciseMode.letterToSound: 'letterToSound',
  ExerciseMode.positionToForm: 'positionToForm',
  ExerciseMode.harakaSequence: 'harakaSequence',
  ExerciseMode.harakaForLetters: 'harakaForLetters',
  ExerciseMode.syllableBuild: 'syllableBuild',
  ExerciseMode.trace: 'trace',
  ExerciseMode.traceFromMemory: 'traceFromMemory',
  ExerciseMode.drawHarakaForSound: 'drawHarakaForSound',
  ExerciseMode.assemble: 'assemble',
  ExerciseMode.sayName: 'sayName',
  ExerciseMode.saySyllable: 'saySyllable',
  ExerciseMode.connectionBuild: 'connectionBuild',
  ExerciseMode.wordBuild: 'wordBuild',
  ExerciseMode.sayWord: 'sayWord',
};
