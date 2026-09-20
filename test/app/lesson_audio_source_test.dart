/// Защита нового материала: запись задания должна иметь приоритет перед
/// записью атома, а старые буквы без поля audioAsset должны звучать как раньше.
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_audio_source.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_exercise_presentation.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = LessonAudioSource();

  test('звук задания важнее звука атома, старые буквы сохраняют путь', () {
    const letter = Atom(
      id: 'ba.isolated',
      kind: AtomKind.letterForm,
      display: 'ب',
      letterId: 'ba',
    );
    const syllable = Atom(
      id: 'ba.fatha',
      kind: AtomKind.syllable,
      display: 'بَ',
      audioAsset: 'audio/syllables/ba_fatha.wav',
    );
    const exercise = Exercise(
      atom: syllable,
      mode: ExerciseMode.soundToLetter,
      level: DistractorLevel.distant,
      audioAsset: 'audio/questions/ba_fatha.wav',
      question: 'Выберите услышанный слог',
    );

    expect(source.forAtom(letter), 'audio/alphabet/ba.wav');
    expect(source.forAtom(syllable), 'audio/syllables/ba_fatha.wav');
    expect(source.forExercise(exercise), 'audio/questions/ba_fatha.wav');
    expect(
      LessonExercisePresentation.from(exercise).prompt,
      'Выберите услышанный слог',
    );
  });
}
