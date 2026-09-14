import 'dart:io';

import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// База, созданная прошлой версией приложения, должна доживать до новой.
/// Тесты обычно работают со свежей базой, поэтому пропущенную миграцию
/// они не ловят — а на устройстве она валила весь экран курса.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('progress_db');
    file = File('${dir.path}/progress.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('база версии 1 доучивается до текущей схемы', () async {
    // Ровно то, что оставляла версия 1: лог атомов и никаких отметок.
    final v1 = ProgressDatabase(NativeDatabase(file));
    await v1.customStatement('DROP TABLE IF EXISTS topic_completions');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final upgraded = ProgressDatabase(NativeDatabase(file));
    await upgraded.completeTopic('m.first', sessionId: 1);
    expect((await upgraded.readCompletions()).map((c) => c.topicId), [
      'm.first',
    ]);
    await upgraded.close();
  });

  test('версия схемы поднята вместе с новой таблицей', () async {
    final db = ProgressDatabase(NativeDatabase(file));
    expect(
      db.schemaVersion,
      greaterThanOrEqualTo(3),
      reason: 'добавили таблицу — поднимите версию, иначе миграция не пойдёт',
    );
    await db.close();
  });

  test('база версии 2 получает итоги сессий', () async {
    final v2 = ProgressDatabase(NativeDatabase(file));
    await v2.customStatement('DROP TABLE IF EXISTS session_summaries');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    final upgraded = ProgressDatabase(NativeDatabase(file));
    await upgraded.finishSession(
      sessionId: 1,
      at: DateTime(2026),
      purpose: LessonPurpose.mixedReview,
      exerciseCount: 20,
      firstTryCorrect: 18,
    );
    expect(await upgraded.readSessionSummaries(), hasLength(1));
    await upgraded.close();
  });
}
