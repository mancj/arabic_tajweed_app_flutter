import '../../../domain/atom.dart';
import '../../../domain/exercise.dart';
import '../../../domain/progress_event.dart';

/// Способ взаимодействия с вопросом. Экран выбирает виджет по нему, а не по
/// тому, буква перед ним, огласовка или слово.
enum LessonInputKind {
  choices,
  tracing,
  formSequence,
  pronunciation,
  placeholder,
}

enum LessonQuestionKind { audio, formSequence, label, glyph }

/// Общий способ показать атом на экране урока. Понятие состоит из текста;
/// остальные виды материала имеют знак или сочетание для показа.
class LessonAtomPresentation {
  const LessonAtomPresentation(this.atom);

  final Atom atom;

  bool get hasGlyph => atom.kind != AtomKind.concept;
}

class LessonExercisePresentation {
  const LessonExercisePresentation({
    required this.input,
    required this.question,
    required this.prompt,
    required this.optionsAreGlyphs,
    required this.audioHintAction,
    this.placeholderHint,
  });

  final LessonInputKind input;
  final LessonQuestionKind question;
  final String prompt;
  final bool optionsAreGlyphs;
  final String audioHintAction;
  final String? placeholderHint;

  factory LessonExercisePresentation.from(Exercise exercise) {
    final mode = exercise.mode;
    final input = switch (mode) {
      ExerciseMode.positionToForm => LessonInputKind.formSequence,
      ExerciseMode.sayName => LessonInputKind.pronunciation,
      _ when mode.isTracing => LessonInputKind.tracing,
      _ when exercise.isChoice => LessonInputKind.choices,
      _ => LessonInputKind.placeholder,
    };
    final question = switch (mode) {
      ExerciseMode.soundToLetter => LessonQuestionKind.audio,
      ExerciseMode.positionToForm => LessonQuestionKind.formSequence,
      ExerciseMode.nameToForm => LessonQuestionKind.label,
      _ => LessonQuestionKind.glyph,
    };
    return LessonExercisePresentation(
      input: input,
      question: question,
      prompt: exercise.question ?? _promptFor(exercise),
      optionsAreGlyphs: switch (mode) {
        ExerciseMode.soundToLetter ||
        ExerciseMode.positionToForm ||
        ExerciseMode.nameToForm => true,
        _ => false,
      },
      audioHintAction: exercise.atom.kind == AtomKind.letterForm
          ? 'Не слышно? Показать название'
          : 'Не слышно? Показать подсказку',
      placeholderHint: _stubHintOf(mode),
    );
  }

  static String _promptFor(Exercise exercise) => switch (exercise.mode) {
    ExerciseMode.positionToForm => 'Расставьте формы буквы по местам',
    ExerciseMode.formToName =>
      exercise.atom.kind == AtomKind.syllable
          ? 'Какие буквы здесь соединены?'
          : 'Как называется эта буква?',
    ExerciseMode.nameToForm =>
      exercise.atom.kind == AtomKind.syllable
          ? 'Выберите сочетание букв'
          : 'Как пишется буква?',
    ExerciseMode.distinguishDots => 'Какая из них — эта буква?',
    ExerciseMode.findInWord => 'Найдите эту букву в слове',
    ExerciseMode.formToPosition => 'Где в слове стоит эта форма?',
    ExerciseMode.soundToLetter => 'Послушайте и выберите букву',
    ExerciseMode.letterToSound => 'Как звучит эта буква?',
    ExerciseMode.trace => 'Обведите по контуру: ${exercise.atom.label}',
    ExerciseMode.traceFromMemory =>
      'Напишите по памяти: ${exercise.atom.label}',
    ExerciseMode.assemble => 'Соберите слог справа налево',
    ExerciseMode.sayName => 'Назовите эту букву вслух',
  };

  static String _stubHintOf(ExerciseMode mode) => switch (mode) {
    ExerciseMode.trace || ExerciseMode.traceFromMemory =>
      'Заглушка. Холст обводки работает, но для этой формы буквы нет SVG '
          'с осевыми линиями — их предстоит нарисовать, см. SPEC.md §12.',
    ExerciseMode.assemble =>
      'Заглушка. Сборка слога появится на этапе 2, когда откроется понятие '
          '«как буквы соединяются».',
    ExerciseMode.soundToLetter || ExerciseMode.letterToSound =>
      'Заглушка. Озвучку ещё не записали: 28 имён букв и 28 звуков '
          'предстоит сгенерировать, см. SPEC.md §12.',
    _ => 'Заглушка: этот режим ещё не собран.',
  };

  String feedbackTitle({required bool correct}) => correct
      ? input == LessonInputKind.pronunciation
            ? 'Правильно произнесено'
            : 'Верно!'
      : 'Попробуйте ещё раз';

  String? feedbackText({
    required bool correct,
    required String answerLabel,
    String? heard,
    int formSequenceCorrectCount = 0,
    bool revealFormSequenceAnswer = false,
  }) {
    if (correct) {
      return switch (input) {
        LessonInputKind.pronunciation =>
          heard == null ? 'Ответ засчитан.' : 'Слышно: $heard.',
        LessonInputKind.formSequence =>
          'Все формы расставлены по своим местам.',
        LessonInputKind.tracing => 'Буква $answerLabel написана правильно.',
        _ => null,
      };
    }
    return switch (input) {
      LessonInputKind.pronunciation when heard != null =>
        'Услышано: $heard. Это буква $answerLabel.',
      LessonInputKind.formSequence =>
        revealFormSequenceAnswer
            ? 'Правильно $formSequenceCorrectCount из 4. '
                  'Сейчас покажем весь порядок, затем соберите его сами.'
            : 'Правильно $formSequenceCorrectCount из 4. '
                  'Верные формы останутся на своих местах.',
      LessonInputKind.tracing =>
        'Попробуйте написать букву $answerLabel ещё раз.',
      _ => null,
    };
  }
}
