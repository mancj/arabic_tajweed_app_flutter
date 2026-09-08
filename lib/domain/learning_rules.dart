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
      Duration(days: 3),
      Duration(days: 7),
      Duration(days: 21),
    ],
    this.errorsBeforeDefer = 5,
    this.failedSessionsBeforeDefer = 3,
    this.deferSessions = 3,
    this.defersBeforeLenient = 2,
    this.maxDeferred = 4,
    this.reviewQueueCap = 25,
    this.reviewPerSession = 4,
    this.sessionsWithoutNewBeforeForcing = 2,
    this.tasksPerSession = 12,
    this.maxTasksPerSession = 16,
  });

  /// Верных подряд с первой попытки для перехода learning → known.
  final int cleanStreakForKnown;

  /// В скольких разных режимах должна набраться эта серия. Одного режима
  /// мало: узнавание в одной рамке ещё не значит, что атом освоен.
  final int distinctModesForKnown;

  /// Интервалы подтверждения на пути known → mastered.
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
  /// очереди повторений. Из двенадцати: не меньше четырёх на возврат,
  /// остальные — на тему урока; чего тема не заполнила, добирает повтор.
  final int reviewPerSession;
  final int sessionsWithoutNewBeforeForcing;
  final int tasksPerSession;
  final int maxTasksPerSession;
}
