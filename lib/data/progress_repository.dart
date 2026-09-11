import 'package:collection/collection.dart';

import '../domain/atom_state.dart';
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
    LearningRules rules = const LearningRules(),
  }) : _db = database,
       _fold = ProgressFold(rules: rules, letterFormIds: letterFormIds);

  final ProgressDatabase _db;
  final ProgressFold _fold;

  Map<String, AtomProgress> _cache = const {};
  List<TopicCompletion> _completions = const [];
  bool _loaded = false;

  /// Номера сессий, встреченные в логе, и те из них, где вводилось новое.
  /// От номера сессии зависят очередь повторений, откладывание и гарантия
  /// темпа, поэтому он считается из лога, а не хранится отдельно.
  Set<int> _sessions = const {};
  Set<int> _sessionsWithNew = const {};
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
    await _db.completeTopic(topicId, sessionId: sessionId, byTest: byTest);
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
    _activityDays = {
      ...log.map((e) => _localDay(e.at)),
      ..._completions.map((c) => _localDay(c.at)),
    };
    _sessions = {
      ...log.map((e) => e.sessionId),
      ..._completions.map((c) => c.sessionId),
    };
    _sessionsWithNew = {
      for (final e in log)
        if (e is AtomIntroduced) e.sessionId,
    };
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
    _sessionsWithNew = {
      ..._sessionsWithNew,
      for (final e in entries)
        if (e is AtomIntroduced) e.sessionId,
    };
  }
}
