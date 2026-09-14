import 'package:collection/collection.dart';

import '../domain/atom_state.dart';
import '../domain/lesson_pacing.dart';
import '../domain/learning_rules.dart';
import '../domain/progress_event.dart';
import 'progress_database.dart';

/// Доступ к прогрессу. Пишет в лог, отдаёт свёрнутое состояние.
///
/// Состояния держатся в памяти и обновляются инкрементально при каждой
/// записи, но это кэш, а не источник истины: его можно выбросить и
/// пересчитать из лога. Ради этой возможности лог и заведён.
class ProgressRepository {
  ProgressRepository({
    required ProgressDatabase database,
    required Set<String> letterFormIds,
    this.baseLetterIds = const {},
    LearningRules rules = const LearningRules(),
    DateTime Function()? now,
  }) : _db = database,
       _rules = rules,
       _now = now ?? DateTime.now,
       _fold = ProgressFold(
         rules: rules,
         letterFormIds: letterFormIds,
         baseLetterIds: baseLetterIds,
       );

  final ProgressDatabase _db;
  final LearningRules _rules;
  final DateTime Function() _now;
  final ProgressFold _fold;
  final Set<String> baseLetterIds;

  Map<String, AtomProgress> _cache = const {};
  List<TopicCompletion> _completions = const [];
  List<SessionSummary> _sessionSummaries = const [];
  bool _loaded = false;

  /// Номера сессий, встреченные в логе, и те из них, где хотя бы один атом
  /// был показан впервые. Повторный просмотр карточки новым не считается.
  /// От номера сессии зависят очередь повторений, откладывание и гарантия
  /// темпа, поэтому он считается из лога, а не хранится отдельно.
  Set<int> _sessions = const {};
  Set<int> _sessionsWithNew = const {};
  Set<String> _introducedAtomIds = const {};
  Set<DateTime> _activityDays = const {};

  /// Дни реальной работы по местному времени, включая незаконченные занятия.
  Future<Set<DateTime>> activityDays() async {
    if (!_loaded) await recompute();
    return Set.unmodifiable(_activityDays);
  }

  static DateTime _localDay(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Future<Map<String, AtomProgress>> progress() async {
    if (!_loaded) await recompute();
    return _cache;
  }

  Future<AtomProgress> of(String atomId) async =>
      (await progress())[atomId] ?? const AtomProgress();

  /// Номер для урока, который начинается сейчас: следующий за последним
  /// в логе. Брошенный на середине урок номер не освобождает — так проще,
  /// и это честно: сессия была, просто не дошла до конца.
  Future<int> nextSessionId() async {
    if (!_loaded) await recompute();
    return (_sessions.maxOrNull ?? 0) + 1;
  }

  /// Сколько последних сессий подряд прошло без ввода новых атомов.
  /// Нужно планировщику для гарантии темпа, см. ТЗ §6.3.
  Future<int> sessionsWithoutNew() async {
    if (!_loaded) await recompute();
    return _sessions
        .sorted((a, b) => b.compareTo(a))
        .takeWhile((id) => !_sessionsWithNew.contains(id))
        .length;
  }

  /// После завершённого урока с новым материалом следующий новый блок в
  /// тот же день открывают только успешные завершённые уроки без нового.
  /// Незаконченный урок не запускает цикл и не засчитывается как повтор.
  Future<PacingSnapshot> pacing({DateTime? now}) async {
    if (!_loaded) await recompute();
    if (baseLetterIds.isEmpty) return const PacingSnapshot();
    final today = _localDay(now ?? _now());
    final todaySummaries = _sessionSummaries
        .where((summary) => _localDay(summary.at) == today)
        .toList();
    final latestNewSession = todaySummaries
        .where((summary) => _sessionsWithNew.contains(summary.sessionId))
        .map((summary) => summary.sessionId)
        .maxOrNull;
    final successfulReviews = latestNewSession == null
        ? 0
        : todaySummaries
              .where(
                (summary) =>
                    summary.sessionId > latestNewSession &&
                    !_sessionsWithNew.contains(summary.sessionId) &&
                    _isSuccessfulReview(summary),
              )
              .length;
    return PacingSnapshot(
      enabled: true,
      hasNewMaterialToday: latestNewSession != null,
      successfulReviewsSinceLatestNew: successfulReviews,
      completedAlphabetCheckpoints: {
        for (final summary in _sessionSummaries)
          if (_purposeOf(summary) == LessonPurpose.alphabetCheckpoint &&
              _isSuccessfulReview(summary) &&
              summary.checkpointLetters != null)
            summary.checkpointLetters!,
      },
    );
  }

  LessonPurpose _purposeOf(SessionSummary summary) =>
      LessonPurpose.values.firstWhereOrNull(
        (purpose) => purpose.name == summary.purpose,
      ) ??
      LessonPurpose.standard;

  bool _isSuccessfulReview(SessionSummary summary) =>
      summary.exerciseCount >= _rules.reviewLessonMinExercises &&
      summary.firstTryCorrect * 100 >=
          summary.exerciseCount * _rules.reviewLessonSuccessPercent;

  Future<void> record(LogEntry entry) async {
    await _db.append(entry);
    await _applyIncrementally([entry]);
  }

  Future<void> recordAll(Iterable<LogEntry> entries) async {
    final list = entries.toList();
    if (list.isEmpty) return;
    await _db.appendAll(list);
    await _applyIncrementally(list);
  }

  /// Стереть прогресс целиком. Кэш пересчитывается из пустого лога.
  Future<void> clear() async {
    await _db.clear();
    await recompute();
  }

  Future<void> finishSession({
    required int sessionId,
    required LessonPurpose purpose,
    required int exerciseCount,
    required int firstTryCorrect,
    int? checkpointLetters,
    DateTime? at,
  }) async {
    await _db.finishSession(
      sessionId: sessionId,
      at: at ?? _now(),
      purpose: purpose,
      exerciseCount: exerciseCount,
      firstTryCorrect: firstTryCorrect,
      checkpointLetters: checkpointLetters,
    );
    _sessionSummaries = await _db.readSessionSummaries();
    _sessions = {..._sessions, sessionId};
    _activityDays = {
      ..._activityDays,
      ..._sessionSummaries.map((summary) => _localDay(summary.at)),
    };
  }

  /// Отметки о пройденных уроках: id темы → как именно закрыт.
  Future<Map<String, TopicCompletion>> completions() async {
    if (!_loaded) await recompute();
    return {for (final c in _completions) c.topicId: c};
  }

  /// Урок, которым занимались последним. Кнопка «Продолжить» ведёт туда,
  /// а не к самому раннему незакрытому: человек сам решил уйти вперёд,
  /// и тянуть его назад — обесценивать это решение.
  Future<String?> lastActiveTopicId() async {
    if (!_loaded) await recompute();
    if (_completions.isEmpty) return null;
    return _completions.reduce((a, b) => a.at.isAfter(b.at) ? a : b).topicId;
  }

  Future<void> completeTopic(
    String topicId, {
    required int sessionId,
    bool byTest = false,
  }) async {
    await _db.completeTopic(
      topicId,
      sessionId: sessionId,
      at: _now(),
      byTest: byTest,
    );
    _completions = await _db.readCompletions();
    _activityDays = {
      ..._activityDays,
      ..._completions.map((c) => _localDay(c.at)),
    };
  }

  /// Полный пересчёт из лога. Нужен при старте и после изменения порогов:
  /// новые правила применяются ко всей истории, а не только к будущему.
  Future<void> recompute() async {
    final log = await _db.readAll();
    _cache = _fold.fold(log);
    _completions = await _db.readCompletions();
    _sessionSummaries = await _db.readSessionSummaries();
    _activityDays = {
      ...log.map((e) => _localDay(e.at)),
      ..._completions.map((c) => _localDay(c.at)),
      ..._sessionSummaries.map((summary) => _localDay(summary.at)),
    };
    _sessions = {
      ...log.map((e) => e.sessionId),
      ..._completions.map((c) => c.sessionId),
      ..._sessionSummaries.map((summary) => summary.sessionId),
    };
    final introducedAtomIds = <String>{};
    final sessionsWithNew = <int>{};
    for (final entry in log.whereType<AtomIntroduced>()) {
      if (introducedAtomIds.add(entry.atomId)) {
        sessionsWithNew.add(entry.sessionId);
      }
    }
    _introducedAtomIds = introducedAtomIds;
    _sessionsWithNew = sessionsWithNew;
    _loaded = true;
  }

  /// Свёртка ассоциативна по атомам, поэтому дописать хвост дешевле,
  /// чем прокручивать весь лог заново.
  Future<void> _applyIncrementally(List<LogEntry> entries) async {
    if (!_loaded) {
      await recompute();
      return;
    }
    final touched = entries.map((e) => e.atomId).toSet();
    final base = {
      for (final id in touched) id: _cache[id] ?? const AtomProgress(),
    };
    _cache = {..._cache, ..._fold.foldOnto(base, entries)};
    _activityDays = {..._activityDays, ...entries.map((e) => _localDay(e.at))};
    _sessions = {..._sessions, ...entries.map((e) => e.sessionId)};
    final introducedAtomIds = {..._introducedAtomIds};
    final sessionsWithNew = {..._sessionsWithNew};
    for (final entry in entries.whereType<AtomIntroduced>()) {
      if (introducedAtomIds.add(entry.atomId)) {
        sessionsWithNew.add(entry.sessionId);
      }
    }
    _introducedAtomIds = introducedAtomIds;
    _sessionsWithNew = sessionsWithNew;
  }
}
