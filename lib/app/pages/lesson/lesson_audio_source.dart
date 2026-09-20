import '../../../data/letter_audio.dart';
import '../../../domain/atom.dart';
import '../../../domain/exercise.dart';

/// Откуда звучит материал. Старые буквы пока используют общий файл имени,
/// новые атомы и отдельные вопросы могут назвать свой файл в контенте.
class LessonAudioSource {
  const LessonAudioSource();

  String? forAtom(Atom atom) =>
      atom.audioAsset ??
      (LetterAudio.has(atom.letterId)
          ? LetterAudio.assetOf(atom.letterId!)
          : null);

  String? forExercise(Exercise exercise) =>
      exercise.audioAsset ?? forAtom(exercise.atom);
}
