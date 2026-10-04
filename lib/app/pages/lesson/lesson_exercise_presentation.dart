import '../../../domain/atom.dart';
import '../../../domain/exercise.dart';
import '../../../domain/progress_event.dart';
import '../../../domain/syllable_build_question.dart';
import '../../../data/rest/syllable_check.dart';

/// Способ взаимодействия с вопросом. Экран выбирает виджет по нему, а не по
/// тому, буква перед ним, огласовка или слово.
enum LessonInputKind {
  choices,
  tracing,
  formSequence,
  syllableBuild,
  pronunciation,
  placeholder,
}

enum LessonQuestionKind {
  audio,
  formSequence,
  harakaSequence,
  harakaForLetters,
  label,
  glyph,
}

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
    required this.isHarakaDrawing,
    this.placeholderHint,
    this.isSyllablePronunciation = false,
    this.sequenceLength = 4,
  });

  final LessonInputKind input;
  final LessonQuestionKind question;
  final String prompt;
  final bool optionsAreGlyphs;
  final String audioHintAction;
  final bool isHarakaDrawing;
  final String? placeholderHint;
  final bool isSyllablePronunciation;
  final int sequenceLength;

  factory LessonExercisePresentation.from(Exercise exercise) {
    final mode = exercise.mode;
    final input = switch (mode) {
      ExerciseMode.positionToForm ||
      ExerciseMode.harakaSequence ||
      ExerciseMode.harakaForLetters => LessonInputKind.formSequence,
      ExerciseMode.syllableBuild => LessonInputKind.syllableBuild,
      ExerciseMode.sayName ||
      ExerciseMode.saySyllable => LessonInputKind.pronunciation,
      _ when mode.isTracing => LessonInputKind.tracing,
      _ when exercise.isChoice => LessonInputKind.choices,
      _ => LessonInputKind.placeholder,
    };
    final question = switch (mode) {
      ExerciseMode.soundToLetter ||
      ExerciseMode.syllableBuild => LessonQuestionKind.audio,
      ExerciseMode.positionToForm => LessonQuestionKind.formSequence,
      ExerciseMode.harakaSequence => LessonQuestionKind.harakaSequence,
      ExerciseMode.harakaForLetters => LessonQuestionKind.harakaForLetters,
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
        ExerciseMode.harakaSequence ||
        ExerciseMode.harakaForLetters ||
        ExerciseMode.nameToForm => true,
        _ => false,
      },
      audioHintAction: exercise.atom.kind == AtomKind.letterForm
          ? 'Не слышно? Показать название'
          : 'Не слышно? Показать подсказку',
      isHarakaDrawing:
          mode == ExerciseMode.drawHarakaForSound ||
          (mode.isTracing && exercise.atom.kind == AtomKind.haraka),
      placeholderHint: _stubHintOf(mode),
      isSyllablePronunciation: mode == ExerciseMode.saySyllable,
      sequenceLength: exercise.resultAtoms.length,
    );
  }

  static String _promptFor(Exercise exercise) => switch (exercise.mode) {
    ExerciseMode.positionToForm => 'Расставьте формы буквы по местам',
    ExerciseMode.harakaSequence => 'Расставьте огласовки по звукам',
    ExerciseMode.harakaForLetters => 'Послушайте и добавьте огласовки',
    ExerciseMode.syllableBuild => 'Соберите слог по звуку',
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
    ExerciseMode.drawHarakaForSound => 'Послушайте и дорисуйте огласовку',
    ExerciseMode.assemble => 'Соберите слог справа налево',
    ExerciseMode.sayName => 'Назовите эту букву вслух',
    ExerciseMode.saySyllable => 'Прочитайте этот слог вслух',
  };

  static String _stubHintOf(ExerciseMode mode) => switch (mode) {
    ExerciseMode.trace ||
    ExerciseMode.traceFromMemory ||
    ExerciseMode.drawHarakaForSound =>
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

  String feedbackTitle({
    required bool correct,
    SyllableBuildEvaluation? syllableBuildEvaluation,
    SyllableCheck? syllableCheck,
  }) {
    if (syllableCheck != null && syllableCheck.matched == correct) {
      return syllableCheck.feedbackTitle;
    }
    final result = syllableBuildEvaluation;
    if (input == LessonInputKind.syllableBuild && result != null) {
      return switch ((result.letterCorrect, result.harakaCorrect)) {
        (true, true) => 'Слог собран правильно',
        (true, false) => 'Буква верная, огласовка отличается',
        (false, true) => 'Огласовка верная, буква отличается',
        (false, false) => 'Буква и огласовка отличаются',
      };
    }
    if (correct && isSyllablePronunciation) return 'Слог прочитан правильно';
    return correct
        ? input == LessonInputKind.pronunciation
              ? 'Правильно произнесено'
              : 'Верно!'
        : 'Попробуйте ещё раз';
  }

  String? feedbackText({
    required bool correct,
    required String answerLabel,
    String? heard,
    SyllableCheck? syllableCheck,
    int formSequenceCorrectCount = 0,
    bool revealFormSequenceAnswer = false,
  }) {
    if (syllableCheck != null && syllableCheck.matched == correct) {
      return syllableCheck.hint;
    }
    if (correct) {
      return switch (input) {
        LessonInputKind.pronunciation =>
          heard == null ? 'Ответ засчитан.' : 'Слышно: $heard.',
        LessonInputKind.formSequence =>
          isHarakaSequence
              ? 'Все огласовки расставлены по звукам.'
              : 'Все формы расставлены по своим местам.',
        LessonInputKind.tracing =>
          isHarakaDrawing
              ? 'Огласовка нарисована правильно.'
              : 'Буква $answerLabel написана правильно.',
        LessonInputKind.syllableBuild => 'Буква и огласовка выбраны верно.',
        _ => null,
      };
    }
    return switch (input) {
      LessonInputKind.pronunciation when heard != null =>
        'Услышано: $heard. Это буква $answerLabel.',
      LessonInputKind.formSequence =>
        revealFormSequenceAnswer
            ? 'Правильно $formSequenceCorrectCount из $sequenceLength. '
                  'Сейчас покажем весь порядок, затем соберите его сами.'
            : 'Правильно $formSequenceCorrectCount из $sequenceLength. '
                  'Верные ${isHarakaSequence ? 'огласовки' : 'формы'} останутся на своих местах.',
      LessonInputKind.tracing =>
        isHarakaDrawing
            ? 'Попробуйте нарисовать огласовку ещё раз.'
            : 'Попробуйте написать букву $answerLabel ещё раз.',
      LessonInputKind.syllableBuild =>
        'Посмотрите на правильный слог. Верная часть останется выбранной '
            'для следующей попытки.',
      _ => null,
    };
  }

  bool get isHarakaSequence =>
      question == LessonQuestionKind.harakaSequence ||
      question == LessonQuestionKind.harakaForLetters;
}
