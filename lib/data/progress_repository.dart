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
    LearningRules rules = const LearningRules(),
  }) : _db = database,
       _fold = ProgressFold(rules: rules);

  final ProgressDatabase _db;
  final ProgressFold _fold;

  Map<String, AtomProgress> _cache = const {};
  List<TopicCompletion> _completions = const [];
  bool _loaded = false;

  Future<Map<String, AtomProgress>> progress() async {
    if (!_loaded) await recompute();
    return _cache;
  }

  Future<AtomProgress> of(String atomId) async =>
      (await progress())[atomId] ?? const AtomProgress();

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
  }

  /// Полный пересчёт из лога. Нужен при старте и после изменения порогов:
  /// новые правила применяются ко всей истории, а не только к будущему.
  Future<void> recompute() async {
    _cache = _fold.fold(await _db.readAll());
    _completions = await _db.readCompletions();
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
  }
}
