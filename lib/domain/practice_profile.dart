import 'package:json_annotation/json_annotation.dart';

import 'atom.dart';
import 'progress_event.dart';

part 'practice_profile.g.dart';

enum PracticeApproach { standard, configured }

/// Правила подбора упражнений внутри сессии. Интервалы и пороги знания
/// остаются в LearningRules; назначение профиля хранится в контенте атома.
@JsonSerializable()
class PracticeProfile {
  const PracticeProfile({
    this.approach = PracticeApproach.configured,
    this.plannedExercises = 2,
    this.maxExercisesPerSession = 3,
    this.maxAtomsPerSession = 8,
    this.initialModes = const [],
    this.reviewModes = const [],
    this.requiredModes = const [],
    this.pronunciationMode,
    this.pronunciationMaxPercent = 15,
    this.preferSameLetters = false,
    this.reviewLessonMinExercises,
  });

  const PracticeProfile.standard() : this(approach: PracticeApproach.standard);

  factory PracticeProfile.fromJson(Map<String, dynamic> json) =>
      _$PracticeProfileFromJson(json);

  final PracticeApproach approach;
  final int plannedExercises;
  final int maxExercisesPerSession;
  final int maxAtomsPerSession;
  final List<ExerciseMode> initialModes;
  final List<ExerciseMode> reviewModes;
  final List<ExerciseMode> requiredModes;
  final ExerciseMode? pronunciationMode;
  final int pronunciationMaxPercent;
  final bool preferSameLetters;
  final int? reviewLessonMinExercises;

  bool get isStandard => approach == PracticeApproach.standard;

  Map<String, dynamic> toJson() => _$PracticeProfileToJson(this);

  void validate(String id) {
    if (isStandard) return;
    if (plannedExercises < 1 ||
        maxExercisesPerSession < plannedExercises ||
        maxAtomsPerSession < 1 ||
        (reviewLessonMinExercises != null && reviewLessonMinExercises! < 1) ||
        initialModes.isEmpty ||
        reviewModes.isEmpty ||
        initialModes.length > plannedExercises ||
        [...initialModes, ...reviewModes].any((mode) => mode.isPronunciation) ||
        pronunciationMaxPercent < 0 ||
        pronunciationMaxPercent > 100 ||
        (pronunciationMode != null && !pronunciationMode!.isPronunciation) ||
        (pronunciationMode != null &&
            (maxExercisesPerSession <= plannedExercises ||
                pronunciationMaxPercent == 0)) ||
        requiredModes.any(
          (mode) => mode.isPronunciation
              ? mode != pronunciationMode
              : !initialModes.contains(mode),
        )) {
      throw StateError('Невыполнимые правила профиля $id');
    }
  }

  /// Проверяет возможности механик, а не назначает подход типу атома.
  void validateFor(Atom atom) {
    if (isStandard) return;
    for (final mode in {
      ...initialModes,
      ...reviewModes,
      ...requiredModes,
      if (pronunciationMode != null) pronunciationMode!,
    }) {
      final supported = switch (mode) {
        ExerciseMode.wordBuild ||
        ExerciseMode.connectionBuild ||
        ExerciseMode.sayWord => atom.wordId != null,
        ExerciseMode.trace ||
        ExerciseMode.traceFromMemory => atom.tracing != null,
        ExerciseMode.drawHarakaForSound =>
          atom.kind == AtomKind.syllable && atom.tracing != null,
        ExerciseMode.sayName =>
          atom.letterId != null && atom.form == LetterForm.isolated,
        ExerciseMode.saySyllable =>
          atom.audioAsset != null &&
              (atom.kind == AtomKind.syllable || atom.kind == AtomKind.haraka),
        ExerciseMode.soundToLetter => atom.kind != AtomKind.concept,
        ExerciseMode.letterToSound =>
          atom.audioAsset != null &&
              (atom.kind == AtomKind.syllable || atom.kind == AtomKind.haraka),
        ExerciseMode.nameToForm || ExerciseMode.formToName =>
          atom.kind == AtomKind.sign ||
              (atom.kind == AtomKind.syllable && atom.audioAsset == null),
        _ => false,
      };
      if (!supported) {
        throw StateError(
          'Профиль ${atom.practiceProfileId}: ${mode.name} '
          'недоступен для ${atom.id}',
        );
      }
    }
  }
}
