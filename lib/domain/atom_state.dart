import 'learning_rules.dart';
import 'progress_event.dart';

/// См. SPEC.md §3. Ошибка сбрасывает атом на одно состояние назад, не в ноль.
enum AtomState { fresh, introduced, learning, known, mastered }

/// Состояние одного атома. Это производная от лога, а не хранимая истина:
/// её можно в любой момент выбросить и пересчитать. Именно эта возможность
/// и есть смысл лога — при смене порогов пересчитываются все пользователи.
class AtomProgress {
  const AtomProgress({
    this.state = AtomState.fresh,
    this.cleanStreak = 0,
    this.modesInStreak = const {},
    this.totalErrors = 0,
    this.failedSessions = const {},
    this.hadActiveSuccess = false,
    this.knownAt,
    this.confirmations = 0,
    this.deferredAtSession,
    this.deferCount = 0,
    this.lastSeenSession,
    this.weak = false,
    this.cleanSinceKnown = 0,
  });

  final AtomState state;
  final int cleanStreak;
  final Set<ExerciseMode> modesInStreak;
  final int totalErrors;
  final Set<int> failedSessions;

  /// Был ли успех в обводке или сборке слова. Без него атом не доходит
  /// до mastered: узнавание не равно воспроизведению.
  final bool hadActiveSuccess;

  final DateTime? knownAt;
  final int confirmations;

  /// Сессия, на которой атом отложен. null — атом в обычной ротации.
  final int? deferredAtSession;
  final int deferCount;
  final int? lastSeenSession;

  /// Чистых ответов подряд с тех пор, как атом в `known`. От этого растёт
  /// интервал повтора; ошибка обнуляет вместе с откатом состояния.
  final int cleanSinceKnown;

  /// Атом засчитан по облегчённому критерию после двух откладываний.
  /// Формально known, но требует добора в контексте слогов и слов —
  /// модель честно помечает, что здесь она знает меньше обычного.
  final bool weak;

  bool isDeferredAt(int session, LearningRules rules) =>
      deferredAtSession != null &&
      session - deferredAtSession! < rules.deferSessions;

  /// Атом возвращается из паузы в облегчённом режиме: далёкие дистракторы,
  /// подсказка про отличительный признак. Долбить тем же способом
  /// бессмысленно — если человек не различил пять раз, шестой не поможет.
  bool returnedEasy(int session, LearningRules rules) =>
      deferCount > 0 && !isDeferredAt(session, rules);

  /// Через сколько сессий после последнего показа атом просится в повтор.
  /// Недоученный — сразу, выученный — по растущему интервалу.
  int reviewIntervalFor(LearningRules rules) {
    if (state.index < AtomState.known.index) return 0;
    final doubled = rules.reviewIntervalBase << cleanSinceKnown;
    return doubled < rules.reviewIntervalCap
        ? doubled
        : rules.reviewIntervalCap;
  }

  /// Сессия, с которой атом пора повторять.
  int dueSession(LearningRules rules) =>
      (lastSeenSession ?? 0) + reviewIntervalFor(rules);

  bool isDueAt(int session, LearningRules rules) =>
      session >= dueSession(rules);

  /// `clearDeferred` отдельным флагом, потому что в `copyWith` null означает
  /// «не менять поле» — иначе снять отложенность было бы нечем.
  AtomProgress copyWith({
    AtomState? state,
    int? cleanStreak,
    Set<ExerciseMode>? modesInStreak,
    int? totalErrors,
    Set<int>? failedSessions,
    bool? hadActiveSuccess,
    DateTime? knownAt,
    int? confirmations,
    int? deferredAtSession,
    bool clearDeferred = false,
    int? deferCount,
    int? lastSeenSession,
    bool? weak,
    int? cleanSinceKnown,
  }) => AtomProgress(
    state: state ?? this.state,
    cleanStreak: cleanStreak ?? this.cleanStreak,
    modesInStreak: modesInStreak ?? this.modesInStreak,
    totalErrors: totalErrors ?? this.totalErrors,
    failedSessions: failedSessions ?? this.failedSessions,
    hadActiveSuccess: hadActiveSuccess ?? this.hadActiveSuccess,
    knownAt: knownAt ?? this.knownAt,
    confirmations: confirmations ?? this.confirmations,
    deferredAtSession: clearDeferred
        ? null
        : (deferredAtSession ?? this.deferredAtSession),
    deferCount: deferCount ?? this.deferCount,
    lastSeenSession: lastSeenSession ?? this.lastSeenSession,
    weak: weak ?? this.weak,
    cleanSinceKnown: cleanSinceKnown ?? this.cleanSinceKnown,
  );
}

/// Свёртка лога в состояния атомов.
class ProgressFold {
  const ProgressFold({this.rules = const LearningRules()});

  final LearningRules rules;

  Map<String, AtomProgress> fold(Iterable<LogEntry> log) =>
      foldOnto(const {}, log);

  /// Продолжить свёртку поверх уже посчитанных состояний. Нужно, чтобы
  /// дописывать хвост лога, не прокручивая его целиком.
  Map<String, AtomProgress> foldOnto(
    Map<String, AtomProgress> base,
    Iterable<LogEntry> log,
  ) {
    final result = {...base};
    for (final entry in log) {
      final current = result[entry.atomId] ?? const AtomProgress();
      result[entry.atomId] = _apply(current, entry);
    }
    return result;
  }

  AtomProgress _apply(AtomProgress p, LogEntry entry) => switch (entry) {
    AtomIntroduced() => p.copyWith(
      state: p.state == AtomState.fresh ? AtomState.introduced : p.state,
      lastSeenSession: entry.sessionId,
    ),
    ProgressEvent() => _applyAnswer(p, entry),
  };

  AtomProgress _applyAnswer(AtomProgress p, ProgressEvent e) {
    if (!e.correct) return _applyError(p, e);

    final active = p.hadActiveSuccess || e.mode.isActive;

    // Медленный или со второй попытки: засчитан, серию не растит и в known
    // не ведёт. Но «показан» → «учится» всё же переводит: атом спросили
    // и он ответил, а иначе медленный человек вечно висел бы в introduced.
    if (!e.isClean) {
      return p.copyWith(
        state: p.state == AtomState.fresh || p.state == AtomState.introduced
            ? AtomState.learning
            : p.state,
        hadActiveSuccess: active,
        lastSeenSession: e.sessionId,
        clearDeferred: true,
      );
    }

    final streak = p.cleanStreak + 1;
    final modes = {...p.modesInStreak, e.mode};

    var next = p.copyWith(
      cleanStreak: streak,
      modesInStreak: modes,
      hadActiveSuccess: active,
      lastSeenSession: e.sessionId,
      clearDeferred: true,
    );

    // Ответ на fresh/introduced сразу поднимает атом в learning, и уже
    // оттуда проверяются условия перехода дальше — иначе атом, отложенный
    // ещё до первого верного ответа, не попадал бы под облегчённый критерий.
    final state = p.state == AtomState.fresh || p.state == AtomState.introduced
        ? AtomState.learning
        : p.state;
    next = next.copyWith(state: state);

    // Выученный ответил чисто ещё раз — интервал до следующего повтора
    // удваивается.
    if (state.index >= AtomState.known.index) {
      next = next.copyWith(cleanSinceKnown: p.cleanSinceKnown + 1);
    }

    return switch (state) {
      AtomState.learning when _reachedKnown(next, e) => next.copyWith(
        state: AtomState.known,
        knownAt: e.at,
        weak: _isLenient(next),
      ),
      AtomState.known when _confirmed(p, e) => _confirm(next, e),
      _ => next,
    };
  }

  bool _isLenient(AtomProgress p) =>
      p.deferCount >= rules.defersBeforeLenient &&
      !(p.cleanStreak >= rules.cleanStreakForKnown &&
          p.modesInStreak.length >= rules.distinctModesForKnown);

  bool _reachedKnown(AtomProgress p, ProgressEvent e) {
    // Облегчённый критерий для атома, который дважды откладывали:
    // иначе он блокирует курс бесконечно.
    if (_isLenient(p)) return true;
    return p.cleanStreak >= rules.cleanStreakForKnown &&
        p.modesInStreak.length >= rules.distinctModesForKnown;
  }

  /// Подтверждение засчитывается, только если прошёл очередной интервал.
  bool _confirmed(AtomProgress p, ProgressEvent e) {
    final knownAt = p.knownAt;
    if (knownAt == null) return false;
    final index = p.confirmations.clamp(0, rules.confirmDelays.length - 1);
    return e.at.difference(knownAt) >= rules.confirmDelays[index];
  }

  AtomProgress _confirm(AtomProgress p, ProgressEvent e) {
    final confirmations = p.confirmations + 1;
    final done = confirmations >= rules.confirmDelays.length;
    // Одних тапов по вариантам мало: без успеха в активной механике
    // атом остаётся в known сколько угодно долго.
    final toMastered = done && p.hadActiveSuccess;
    return p.copyWith(
      confirmations: confirmations,
      knownAt: e.at,
      state: toMastered ? AtomState.mastered : AtomState.known,
    );
  }

  AtomProgress _applyError(AtomProgress p, ProgressEvent e) {
    final errors = p.totalErrors + 1;
    final failed = {...p.failedSessions, e.sessionId};
    final shouldDefer =
        errors >= rules.errorsBeforeDefer ||
        failed.length >= rules.failedSessionsBeforeDefer;

    return p.copyWith(
      state: _stepBack(p.state),
      cleanStreak: 0,
      cleanSinceKnown: 0,
      modesInStreak: const {},
      // При откладывании счётчики обнуляются: иначе атом, однажды перешедший
      // порог, откладывался бы после каждой следующей ошибки.
      totalErrors: shouldDefer ? 0 : errors,
      failedSessions: shouldDefer ? const {} : failed,
      lastSeenSession: e.sessionId,
      deferredAtSession: shouldDefer ? e.sessionId : p.deferredAtSession,
      deferCount: shouldDefer ? p.deferCount + 1 : p.deferCount,
    );
  }

  AtomState _stepBack(AtomState state) => switch (state) {
    AtomState.mastered => AtomState.known,
    AtomState.known => AtomState.learning,
    AtomState.learning => AtomState.learning,
    AtomState.introduced => AtomState.introduced,
    AtomState.fresh => AtomState.fresh,
  };
}
