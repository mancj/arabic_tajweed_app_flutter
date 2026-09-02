/// Режимы упражнений. Одна переиспользуемая сцена, девять режимов.
/// См. SPEC.md §4.
enum ExerciseMode {
  formToName,
  nameToForm,
  findInWord,
  distinguishDots,
  formToPosition,
  soundToLetter,
  letterToSound,
  trace,
  assemble,
}

extension ExerciseModeX on ExerciseMode {
  /// Активная механика — воспроизведение, а не узнавание. Атом не может
  /// дойти до mastered на одних тапах по вариантам.
  bool get isActive =>
      this == ExerciseMode.trace || this == ExerciseMode.assemble;
}

/// Запись лога. Лог append-only и упорядочен по времени.
///
/// Иерархия голая `sealed`, а не freezed-union: подтипы различаются
/// поведением при свёртке, и исчерпывающий `switch` читается лучше,
/// чем сгенерированный `when`. См. CLAUDE.md.
sealed class LogEntry {
  const LogEntry({
    required this.atomId,
    required this.sessionId,
    required this.at,
  });

  final String atomId;

  /// Нужен, чтобы отличать «три ошибки подряд за один заход» от
  /// «три неудачные встречи в разных сессиях» — это разные сигналы.
  final int sessionId;
  final DateTime at;
}

/// Атом показан в блоке «новое», но ещё не спрашивался.
class AtomIntroduced extends LogEntry {
  const AtomIntroduced({
    required super.atomId,
    required super.sessionId,
    required super.at,
  });
}

/// Ответ на задание. Источник истины — именно лог, а не снимок состояния:
/// почти все правила курса это утверждения об истории («3 верных подряд
/// с первой попытки в ≥2 режимах»), а пороги ещё будут калиброваться.
/// Состояние атома вычисляется свёрткой. См. SPEC.md §11.
class ProgressEvent extends LogEntry {
  const ProgressEvent({
    required super.atomId,
    required super.sessionId,
    required super.at,
    required this.mode,
    required this.correct,
    required this.attempt,
    required this.fastEnough,
  });

  final ExerciseMode mode;
  final bool correct;

  /// 1 — с первой попытки. Только такие ответы двигают атом вперёд.
  final int attempt;

  /// Уложился в порог скорости. Узнавание становится чтением только
  /// когда оно автоматическое, поэтому медленный верный ответ
  /// засчитывается, но прогресса не даёт.
  final bool fastEnough;

  /// Ответ, который двигает атом вперёд по состояниям.
  bool get isClean => correct && attempt == 1 && fastEnough;
}
