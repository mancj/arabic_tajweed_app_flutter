import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/progress_event.dart';
import '../domain/lesson_pacing.dart';

part 'progress_database.g.dart';

/// Лог событий. Append-only: строки только добавляются, никогда не меняются.
/// Состояние атомов из него вычисляется свёрткой и нигде не хранится как
/// истина — именно это позволяет пересчитать прогресс после калибровки
/// порогов. См. SPEC.md §11.
class LogRows extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'introduced' или 'answer'. Дискриминатор подтипа LogEntry.
  TextColumn get kind => text()();

  TextColumn get atomId => text()();
  IntColumn get sessionId => integer()();
  DateTimeColumn get at => dateTime()();

  /// Дальше — поля только для 'answer'.
  TextColumn get mode => text().nullable()();
  BoolColumn get correct => boolean().nullable()();
  IntColumn get attempt => integer().nullable()();
  BoolColumn get fastEnough => boolean().nullable()();
}

/// Отметки о пройденных уроках. Отдельно от лога атомов: «урок пройден» —
/// это факт о занятии, а не о знании. Раньше их путали, и закрытый урок
/// выглядел недоделанным из-за недобранной освоенности букв.
class TopicCompletions extends Table {
  TextColumn get topicId => text()();
  IntColumn get sessionId => integer()();
  DateTimeColumn get at => dateTime()();

  /// Урок не проходили, а сдали тест «Уже знаю».
  BoolColumn get byTest => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {topicId};
}

/// Завершённые занятия. Это сырой итог, а не готовый вердикт: порог
/// успешности смешанного повтора применяется в репозитории и может быть
/// откалиброван без потери истории.
class SessionSummaries extends Table {
  IntColumn get sessionId => integer()();
  DateTimeColumn get at => dateTime()();
  TextColumn get purpose => text()();
  IntColumn get exerciseCount => integer()();
  IntColumn get firstTryCorrect => integer()();
  IntColumn get checkpointLetters => integer().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

@DriftDatabase(tables: [LogRows, TopicCompletions, SessionSummaries])
class ProgressDatabase extends _$ProgressDatabase {
  ProgressDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'progress',
              // Web-сборка: sqlite3.wasm и drift_worker.js лежат в web/.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 3;

  /// Без миграции база, созданная прошлой версией приложения, остаётся
  /// без новых таблиц — и падает на первом же запросе. В тестах это не
  /// видно: там база всегда создаётся с нуля.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2: отметки о пройденных уроках отделены от лога атомов.
      if (from < 2) await m.createTable(topicCompletions);
      // v3: только завершённое смешанное занятие даёт допуск к новым
      // буквам; одного ответа в брошенном уроке недостаточно.
      if (from < 3) await m.createTable(sessionSummaries);
    },
  );

  Future<void> append(LogEntry entry) =>
      into(logRows).insert(_toCompanion(entry));

  Future<void> appendAll(Iterable<LogEntry> entries) =>
      batch((b) => b.insertAll(logRows, entries.map(_toCompanion).toList()));

  /// Порядок по id, а не по времени: часы на устройстве могут прыгнуть,
  /// а порядок записи в лог — нет.
  Future<List<LogEntry>> readAll() async {
    final rows = await (select(
      logRows,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
    return rows.map(_toDomain).toList();
  }

  Future<void> completeTopic(
    String topicId, {
    required int sessionId,
    DateTime? at,
    bool byTest = false,
  }) => into(topicCompletions).insertOnConflictUpdate(
    TopicCompletionsCompanion.insert(
      topicId: topicId,
      sessionId: sessionId,
      at: at ?? DateTime.now(),
      byTest: Value(byTest),
    ),
  );

  Future<List<TopicCompletion>> readCompletions() =>
      select(topicCompletions).get();

  Future<void> finishSession({
    required int sessionId,
    required DateTime at,
    required LessonPurpose purpose,
    required int exerciseCount,
    required int firstTryCorrect,
    int? checkpointLetters,
  }) => into(sessionSummaries).insert(
    SessionSummariesCompanion.insert(
      sessionId: Value(sessionId),
      at: at,
      purpose: purpose.name,
      exerciseCount: exerciseCount,
      firstTryCorrect: firstTryCorrect,
      checkpointLetters: Value(checkpointLetters),
    ),
    mode: InsertMode.insertOrIgnore,
  );

  Future<List<SessionSummary>> readSessionSummaries() =>
      select(sessionSummaries).get();

  /// Стереть весь лог. Нужно при отладке контента: граф и тексты меняются,
  /// а пройденные уроки заново не показываются — планировщик ведёт дальше.
  Future<void> clear() async {
    await delete(logRows).go();
    await delete(topicCompletions).go();
    await delete(sessionSummaries).go();
  }

  Future<int> get eventCount async => (await select(logRows).get()).length;

  LogRowsCompanion _toCompanion(LogEntry entry) => switch (entry) {
    AtomIntroduced() => LogRowsCompanion.insert(
      kind: 'introduced',
      atomId: entry.atomId,
      sessionId: entry.sessionId,
      at: entry.at,
    ),
    KnowledgeConfirmed() => LogRowsCompanion.insert(
      kind: 'confirmed',
      atomId: entry.atomId,
      sessionId: entry.sessionId,
      at: entry.at,
    ),
    ProgressEvent() => LogRowsCompanion.insert(
      kind: 'answer',
      atomId: entry.atomId,
      sessionId: entry.sessionId,
      at: entry.at,
      mode: Value(entry.mode.name),
      correct: Value(entry.correct),
      attempt: Value(entry.attempt),
      fastEnough: Value(entry.fastEnough),
    ),
  };

  LogEntry _toDomain(LogRow row) => switch (row.kind) {
    'introduced' => AtomIntroduced(
      atomId: row.atomId,
      sessionId: row.sessionId,
      at: row.at,
    ),
    'confirmed' => KnowledgeConfirmed(
      atomId: row.atomId,
      sessionId: row.sessionId,
      at: row.at,
    ),
    'answer' => ProgressEvent(
      atomId: row.atomId,
      sessionId: row.sessionId,
      at: row.at,
      mode: ExerciseMode.values.byName(row.mode!),
      correct: row.correct!,
      attempt: row.attempt!,
      fastEnough: row.fastEnough!,
    ),
    final unknown => throw StateError('неизвестный kind: $unknown'),
  };
}
