import 'atom.dart';
import 'progress_event.dart';

/// Уровень сложности дистракторов. Растёт по мере освоения атома:
/// минимальная пара — это экзамен, а не стартовый режим. Показать её
/// сразу на новой букве значит провалить человека за то, что он ещё
/// не дошёл, и запустить откладывание там, где всё в порядке.
/// См. SPEC.md §4.
enum DistractorLevel {
  /// Далёкие по форме: ب против س, م. Тренируем образ буквы целиком.
  distant,

  /// Смешанные. Узнавание среди похожего.
  mixed,

  /// Минимальная пара: ب ت ث. Различение по точкам.
  minimalPair,
}

/// Одно задание сессии. Строится генератором, а не хранится в контенте:
/// набор вариантов зависит от того, что пользователь уже проходил.
class Exercise {
  const Exercise({
    required this.atom,
    required this.mode,
    required this.level,
    this.options = const [],
    this.answerIndex = -1,
    this.isReview = false,
  });

  /// Задание без выбора: обводка, сборка, аудио. Ответ не выбирается
  /// из вариантов, а строится, поэтому исход приходит снаружи —
  /// от холста обводки или от кнопки заглушки.
  ///
  /// Верный исход это [directAnswer], любой другой индекс — ошибка.
  /// Ноль, а не -1: сессия сверяет присланный индекс с [answerIndex],
  /// и «нет верного варианта» превращало бы верный ответ в ошибку.
  const Exercise.direct({
    required this.atom,
    required this.mode,
    this.level = DistractorLevel.distant,
    this.isReview = false,
  }) : options = const [],
       answerIndex = directAnswer;

  /// Индекс, которым отмечается верный исход задания без выбора.
  static const directAnswer = 0;

  /// Индекс, которым отмечается ошибка в задании без выбора.
  static const directMiss = -1;

  /// Атом, о котором это задание. Именно он получит результат в лог.
  final Atom atom;
  final ExerciseMode mode;

  /// Варианты ответа. Пусто у режимов без выбора — обводки и сборки,
  /// где ответ строится, а не выбирается.
  final List<Atom> options;

  /// Индекс верного варианта; -1 у режимов без выбора.
  final int answerIndex;
  final DistractorLevel level;

  /// Задание из блока повторения, а не по новому атому.
  final bool isReview;

  /// Режим с выбором из вариантов. Обводка и сборка — нет.
  bool get isChoice => options.isNotEmpty;

  Atom get answer => isChoice ? options[answerIndex] : atom;
}
