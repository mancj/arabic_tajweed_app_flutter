import 'atom.dart';

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
    this.sessionsWithoutNewBeforeForcing = 2,
    this.tasksPerSession = 20,
    this.maxTasksPerSession = 26,
    this.tracingMissesBeforeReveal = 3,
    this.sayNameAttempts = 2,
    this.reviewIntervalBase = 2,
    this.reviewIntervalCap = 16,
  });

  /// Верных подряд с первой попытки для перехода learning → known.
  final int cleanStreakForKnown;

  /// В скольких разных режимах должна набраться эта серия. Одного режима
  /// мало: узнавание в одной рамке ещё не значит, что атом освоен.
  final int distinctModesForKnown;

  /// Интервалы подтверждения на пути known → mastered. Каждый считается
  /// от предыдущего подтверждения, так что до mastered минимум их сумма:
  /// две недели — столько, сколько отведено на алфавит. С 1/3/7/21 буква
  /// закреплялась бы дольше, чем длится курс.
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
  final int sessionsWithoutNewBeforeForcing;

  /// Сколько заданий в уроке. Ошибки уходят в конец очереди, поэтому
  /// сессия может вырасти, но не выше [maxTasksPerSession].
  final int tasksPerSession;
  final int maxTasksPerSession;

  /// Каждую форму темы спрашиваем; отдельную букву ещё пишем в двух
  /// режимах и называем вслух. Понятия проходят только через объяснение.
  int minimumExercises(Atom atom) => switch (atom) {
    Atom(kind: AtomKind.concept) => 0,
    Atom(letterId: String(), form: LetterForm.isolated) => 3,
    _ => 1,
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

  /// Через сколько сессий выученный атом просится в повтор. Интервал
  /// удваивается после каждого чистого повтора: 2, 4, 8… до
  /// [reviewIntervalCap]; ошибка возвращает атом в learning, и счёт
  /// начинается заново. Недоученные атомы просятся каждый урок. Без этого
  /// очередь крутила всех по кругу, и алиф к концу курса попадался так же
  /// часто, как буква из прошлого урока. См. SPEC.md §6.2.
  final int reviewIntervalBase;
  final int reviewIntervalCap;
}
