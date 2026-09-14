import 'atom.dart';
import 'progress_event.dart';

/// Все пороги курса в одном месте. Каждое число здесь — гипотеза,
/// подлежащая калибровке на реальных данных; лог событий как раз и
/// позволяет пересчитать прогресс задним числом при их изменении.
/// См. SPEC.md §3, §5, §6.4.
class LearningRules {
  const LearningRules({
    this.cleanStreakForKnown = 3,
    this.distinctModesForKnown = 2,
    this.confirmDelays = const [
      Duration(days: 1),
      Duration(days: 2),
      Duration(days: 4),
      Duration(days: 7),
    ],
    this.errorsBeforeDefer = 5,
    this.failedSessionsBeforeDefer = 3,
    this.deferSessions = 3,
    this.defersBeforeLenient = 2,
    this.maxDeferred = 4,
    this.reviewQueueCap = 25,
    this.reviewPerSession = 4,
    this.focusedReviewTasks = 8,
    this.sessionsWithoutNewBeforeForcing = 2,
    this.reviewsBeforeNextNewLesson = 2,
    this.reviewLessonSuccessPercent = 80,
    this.reviewLessonMinExercises = 8,
    this.recentMaterialMaxPercent = 40,
    this.alphabetCheckpointLetters = const [7, 15, 21, 28],
    this.connectedFormCleanStreakForKnown = 2,
    this.tasksPerSession = 20,
    this.narrowLetterExercises = 4,
    this.tracingMissesBeforeReveal = 3,
    this.sayNameAttempts = 2,
    this.letterReviewIntervals = const [1, 2, 4],
    this.reviewIntervalBase = 2,
    this.reviewIntervalCap = 16,
    this.requirePronunciation = true,
  });

  /// Верных подряд с первой попытки для перехода learning → known,
  /// независимо от скорости. Быстрота нужна для дальнейшего закрепления.
  final int cleanStreakForKnown;

  /// В скольких разных режимах должна набраться эта серия. Одного режима
  /// мало: узнавание в одной рамке ещё не значит, что атом освоен.
  final int distinctModesForKnown;

  /// Календарные интервалы подтверждения для материала кроме букв.
  /// Буквы используют [letterReviewIntervals].
  final List<Duration> confirmDelays;

  final int errorsBeforeDefer;
  final int failedSessionsBeforeDefer;

  /// На сколько сессий атом уходит из ротации. Пауза работает лучше
  /// долбёжки: шестой показ подряд ничего не даёт, человек уже угадывает.
  final int deferSessions;

  /// После скольких откладываний атом засчитывается по облегчённому
  /// критерию, чтобы не блокировать курс бесконечно.
  final int defersBeforeLenient;

  /// Потолок отложенных. Предохранитель на предохранитель: без него
  /// человек с плохим стартом набирает десяток отложенных букв —
  /// формально не застрял, фактически не выучил ничего.
  final int maxDeferred;

  final int reviewQueueCap;

  /// Сколько заданий в уроке гарантированно отдаётся старым буквам из
  /// очереди повторений. Из двадцати: не меньше четырёх на возврат,
  /// остальные — на тему урока; чего тема не заполнила, добирает повтор.
  final int reviewPerSession;

  /// Закрепление пробелов задаёт размер первого блока, а остаток занятия
  /// после него планируется заново.
  final int focusedReviewTasks;
  final int sessionsWithoutNewBeforeForcing;

  /// После урока с новым материалом алфавита столько успешных занятий
  /// без нового нужно пройти в тот же день, чтобы открыть следующий блок.
  final int reviewsBeforeNextNewLesson;

  /// Успех занятия-повторения: доля заданий, выполненных с первой попытки.
  /// Скорость сюда не входит — медленный правильный ответ остаётся знанием.
  final int reviewLessonSuccessPercent;
  final int reviewLessonMinExercises;

  /// Когда старого материала достаточно, последний введённый набор не может
  /// занять больше этой доли смешанного занятия.
  final int recentMaterialMaxPercent;

  /// Границы цельных отрезков алфавита. Они совпадают с концами авторских
  /// групп и дают блоки по 7, 8, 6 и 7 букв.
  final List<int> alphabetCheckpointLetters;

  /// Соединённую форму в уроке проверяют отдельно и в сборке семейства.
  /// Этих двух разных успешных проверок достаточно для первого `known`;
  /// изолированная буква по-прежнему требует три встречи и письмо с голосом.
  final int connectedFormCleanStreakForKnown;

  int cleanStreakRequiredFor(Atom atom) =>
      atom.kind == AtomKind.letterForm &&
          atom.form != null &&
          atom.form != LetterForm.isolated
      ? connectedFormCleanStreakForKnown
      : cleanStreakForKnown;

  /// Верхний бюджет обычной сессии. Пара отдельных букв может закончиться
  /// раньше, только когда знакомого старого материала для остатка нет.
  final int tasksPerSession;

  /// Сколько встреч получает каждая буква в узком блоке из двух отдельных
  /// букв: два вида письма, произношение и одно узнавание. Если голос
  /// недоступен, его место может занять второе узнавание.
  final int narrowLetterExercises;

  /// Каждую форму темы спрашиваем; отдельную букву ещё пишем в двух
  /// режимах и называем вслух. Понятия проходят только через объяснение.
  int minimumExercises(Atom atom) => switch (atom) {
    Atom(kind: AtomKind.concept) => 0,
    Atom(letterId: String(), form: LetterForm.isolated) => 3,
    _ => 1,
  };

  /// Базовую букву недостаточно узнать в тестах: до продвижения дальше
  /// нужно успешно назвать её и выполнить оба доступных режима письма.
  Set<ExerciseMode> requiredPracticeModes(Atom atom) => switch (atom) {
    Atom(letterId: String(), form: LetterForm.isolated) => {
      if (atom.tracing != null) ...{
        ExerciseMode.trace,
        ExerciseMode.traceFromMemory,
      },
      if (requirePronunciation) ExerciseMode.sayName,
    },
    _ => const {},
  };

  /// После скольких промахов подряд по одной части буквы холст показывает,
  /// как она пишется: открывает контур и показ. Это подсказка, а не ошибка:
  /// человек обводит по ней, и ответ засчитывается верным. Без этого тот,
  /// у кого не выходит линия, застревал бы на букве без помощи сколько
  /// угодно долго. См. SPEC.md §5.
  final int tracingMissesBeforeReveal;

  /// Сколько записей даётся в задании «назови букву», прежде чем
  /// несовпадение засчитается ошибкой. Первый промах — подсказка: сервер
  /// показывает, что услышал, и человек пробует ещё раз. Плохая запись
  /// (тихо, шумно) попытку не тратит. См. SPEC.md §4.
  final int sayNameAttempts;

  /// Буквы и их соединённые формы закрепляются в разных занятиях, без
  /// календарного ожидания. После `known` они возвращаются через 1, 2 и 4
  /// сессии; каждый своевременный чистый повтор даёт одно подтверждение.
  final List<int> letterReviewIntervals;

  /// Через сколько сессий просится в повтор материал кроме букв. Интервал
  /// удваивается после каждого чистого ответа: 2, 4, 8… до
  /// [reviewIntervalCap]; ошибка возвращает атом в learning, и счёт
  /// начинается заново. Недоученные атомы просятся каждый урок. Без этого
  /// очередь крутила всех по кругу, и алиф к концу курса попадался так же
  /// часто, как буква из прошлого урока. См. SPEC.md §6.2.
  final int reviewIntervalBase;
  final int reviewIntervalCap;

  /// Голос входит в обязательную практику, только пока человек может и
  /// хочет им пользоваться. Отключение не создаёт поддельного ответа.
  final bool requirePronunciation;

  LearningRules copyWith({bool? requirePronunciation}) => LearningRules(
    cleanStreakForKnown: cleanStreakForKnown,
    distinctModesForKnown: distinctModesForKnown,
    confirmDelays: confirmDelays,
    errorsBeforeDefer: errorsBeforeDefer,
    failedSessionsBeforeDefer: failedSessionsBeforeDefer,
    deferSessions: deferSessions,
    defersBeforeLenient: defersBeforeLenient,
    maxDeferred: maxDeferred,
    reviewQueueCap: reviewQueueCap,
    reviewPerSession: reviewPerSession,
    focusedReviewTasks: focusedReviewTasks,
    sessionsWithoutNewBeforeForcing: sessionsWithoutNewBeforeForcing,
    reviewsBeforeNextNewLesson: reviewsBeforeNextNewLesson,
    reviewLessonSuccessPercent: reviewLessonSuccessPercent,
    reviewLessonMinExercises: reviewLessonMinExercises,
    recentMaterialMaxPercent: recentMaterialMaxPercent,
    alphabetCheckpointLetters: alphabetCheckpointLetters,
    connectedFormCleanStreakForKnown: connectedFormCleanStreakForKnown,
    tasksPerSession: tasksPerSession,
    narrowLetterExercises: narrowLetterExercises,
    tracingMissesBeforeReveal: tracingMissesBeforeReveal,
    sayNameAttempts: sayNameAttempts,
    letterReviewIntervals: letterReviewIntervals,
    reviewIntervalBase: reviewIntervalBase,
    reviewIntervalCap: reviewIntervalCap,
    requirePronunciation: requirePronunciation ?? this.requirePronunciation,
  );
}
