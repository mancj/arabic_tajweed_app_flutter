import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProgressDatabase db;
  late ProgressRepository repo;
  final t0 = DateTime(2026, 1, 1);

  setUp(() {
    db = ProgressDatabase(NativeDatabase.memory());
    repo = ProgressRepository(
      database: db,
      letterFormIds: const {'ba.isolated'},
      baseLetterIds: const {'ba.isolated', 'ta.isolated'},
    );
  });

  tearDown(() => db.close());

  ProgressEvent answer({
    bool correct = true,
    ExerciseMode mode = ExerciseMode.formToName,
    int session = 1,
  }) => ProgressEvent(
    atomId: 'ba.isolated',
    sessionId: session,
    at: t0,
    mode: mode,
    correct: correct,
    attempt: 1,
    fastEnough: true,
  );

  test('номер сессии — следующий за последним в логе', () async {
    expect(await repo.nextSessionId(), 1);
    await repo.recordAll([
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: t0),
      answer(session: 3),
    ]);
    expect(await repo.nextSessionId(), 4);
  });

  test('считает сессии подряд без новых атомов', () async {
    await repo.recordAll([
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: t0),
      answer(session: 2),
      answer(session: 3),
    ]);
    expect(await repo.sessionsWithoutNew(), 2);

    await repo.record(
      AtomIntroduced(atomId: 'ta.isolated', sessionId: 4, at: t0),
    );
    expect(await repo.sessionsWithoutNew(), 0);
  });

  test('событие переживает круг через базу', () async {
    await repo.record(answer());
    final log = await db.readAll();
    expect(log, hasLength(1));
    final entry = log.single as ProgressEvent;
    expect(entry.atomId, 'ba.isolated');
    expect(entry.mode, ExerciseMode.formToName);
    expect(entry.fastEnough, isTrue);
  });

  test('оба подтипа записи различаются при чтении', () async {
    await repo.recordAll([
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: t0),
      answer(),
    ]);
    final log = await db.readAll();
    expect(log.first, isA<AtomIntroduced>());
    expect(log.last, isA<ProgressEvent>());
  });

  test('инкрементальная свёртка совпадает с полным пересчётом', () async {
    await repo.recordAll([
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: t0),
      answer(),
      answer(),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.nameToForm),
    ]);
    final incremental = (await repo.of('ba.isolated')).state;

    await repo.recompute();
    expect((await repo.of('ba.isolated')).state, incremental);
    expect(incremental, AtomState.known);
  });

  test('состояние восстанавливается из лога после перезапуска', () async {
    await repo.recordAll([answer(), answer(correct: false, session: 2)]);

    final restarted = ProgressRepository(
      database: db,
      letterFormIds: const {'ba.isolated'},
    );
    expect((await restarted.of('ba.isolated')).totalErrors, 1);
    expect((await restarted.of('ba.isolated')).cleanStreak, 0);
  });

  // Правило букв должно одинаково работать в живом кэше и после полного
  // пересчёта журнала при следующем запуске приложения.
  test('три интервальных сессии закрепляют букву после перезапуска', () async {
    await repo.recordAll([
      answer(mode: ExerciseMode.trace),
      answer(mode: ExerciseMode.nameToForm),
      answer(mode: ExerciseMode.trace),
      answer(session: 2),
      answer(session: 4),
      answer(session: 8),
    ]);
    expect((await repo.of('ba.isolated')).state, AtomState.mastered);

    final restarted = ProgressRepository(
      database: db,
      letterFormIds: const {'ba.isolated'},
    );
    expect((await restarted.of('ba.isolated')).state, AtomState.mastered);
  });

  // Выполненные режимы не теряются при ошибке или перезапуске и не
  // засчитываются за один лишь показ задания либо неверный ответ.
  test(
    'обязательная практика восстанавливается из существующего журнала',
    () async {
      await repo.recordAll([
        AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: t0),
        answer(mode: ExerciseMode.trace),
        answer(mode: ExerciseMode.traceFromMemory, session: 2),
        answer(mode: ExerciseMode.sayName, correct: false, session: 2),
      ]);
      final expected = {ExerciseMode.trace, ExerciseMode.traceFromMemory};
      expect((await repo.of('ba.isolated')).successfulModes, expected);
      final restarted = ProgressRepository(
        database: db,
        letterFormIds: const {'ba.isolated'},
      );
      expect((await restarted.of('ba.isolated')).successfulModes, expected);
      await restarted.record(answer(mode: ExerciseMode.sayName, session: 3));
      expect((await restarted.of('ba.isolated')).successfulModes, {
        ...expected,
        ExerciseMode.sayName,
      });
      await restarted.recompute();
      expect((await restarted.of('ba.isolated')).successfulModes, {
        ...expected,
        ExerciseMode.sayName,
      });
    },
  );

  test('порядок чтения — по порядку записи, а не по времени', () async {
    await repo.recordAll([
      ProgressEvent(
        atomId: 'a',
        sessionId: 1,
        at: t0.add(const Duration(days: 5)),
        mode: ExerciseMode.formToName,
        correct: true,
        attempt: 1,
        fastEnough: true,
      ),
      answer(),
    ]);
    final log = await db.readAll();
    expect(log.map((e) => e.atomId), ['a', 'ba.isolated']);
  });

  // Неделя не должна терять незаконченные занятия после перезапуска,
  // считать каждый ответ отдельным днём или оставаться после сброса.
  test('дни активности берутся из лога по местному календарю', () async {
    expect(await repo.activityDays(), isEmpty);
    final utc = DateTime.utc(2026, 9, 9, 23, 40);
    final local = utc.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    await repo.recordAll([
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: utc),
      KnowledgeConfirmed(atomId: 'ba.isolated', sessionId: 1, at: utc),
    ]);
    expect(await repo.activityDays(), {day});
    expect(
      await ProgressRepository(
        database: db,
        letterFormIds: const {'ba.isolated'},
      ).activityDays(),
      {day},
    );
    await repo.clear();
    expect(await repo.activityDays(), isEmpty);
  });

  // Брошенный или плохо выполненный повтор не открывает новый материал;
  // более поздний новый урок начинает отсчёт двух повторений заново.
  test('два успешных урока без нового открывают следующий блок', () async {
    final day = DateTime(2026, 9, 13, 10);
    await repo.record(
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 1, at: day),
    );
    await repo.finishSession(
      sessionId: 1,
      purpose: LessonPurpose.standard,
      exerciseCount: 20,
      firstTryCorrect: 20,
      at: day,
    );
    var pacing = await repo.pacing(now: day);
    expect(pacing.hasNewMaterialToday, isTrue);
    expect(pacing.successfulReviewsSinceLatestNew, 0);
    expect(pacing.canIntroduceNewMaterial(repoRules), isFalse);

    // Название плана не важно: засчитывается любой завершённый урок без
    // нового, если он достаточно длинный и правильно выполнен.
    await repo.finishSession(
      sessionId: 2,
      purpose: LessonPurpose.standard,
      exerciseCount: 20,
      firstTryCorrect: 20,
      at: day,
    );
    await repo.finishSession(
      sessionId: 3,
      purpose: LessonPurpose.mixedReview,
      exerciseCount: 20,
      firstTryCorrect: 15,
      at: day,
    );
    await repo.finishSession(
      sessionId: 4,
      purpose: LessonPurpose.mixedReview,
      exerciseCount: 20,
      firstTryCorrect: 16,
      at: day,
    );
    pacing = await repo.pacing(now: day);
    expect(pacing.successfulReviewsSinceLatestNew, 2);
    expect(pacing.canIntroduceNewMaterial(repoRules), isTrue);

    // Новый материал может быть формой или понятием, не только отдельной
    // буквой. После него прежние повторы больше не считаются.
    await repo.record(
      AtomIntroduced(atomId: 'concept.forms', sessionId: 5, at: day),
    );
    await repo.finishSession(
      sessionId: 5,
      purpose: LessonPurpose.standard,
      exerciseCount: 20,
      firstTryCorrect: 20,
      at: day,
    );
    pacing = await repo.pacing(now: day);
    expect(pacing.successfulReviewsSinceLatestNew, 0);
    expect(pacing.canIntroduceNewMaterial(repoRules), isFalse);

    await repo.finishSession(
      sessionId: 6,
      purpose: LessonPurpose.alphabetCheckpoint,
      exerciseCount: 20,
      firstTryCorrect: 18,
      checkpointLetters: 7,
      at: day,
    );
    await repo.finishSession(
      sessionId: 7,
      purpose: LessonPurpose.mixedReview,
      exerciseCount: 8,
      firstTryCorrect: 8,
      at: day,
    );

    // Повторная историческая запись AtomIntroduced для уже знакомой буквы
    // не превращает ручной повтор темы в новый материал.
    await repo.record(
      AtomIntroduced(atomId: 'ba.isolated', sessionId: 8, at: day),
    );
    await repo.finishSession(
      sessionId: 8,
      purpose: LessonPurpose.standard,
      exerciseCount: 20,
      firstTryCorrect: 20,
      at: day,
    );
    // События брошенного занятия без итоговой записи не считаются уроком.
    await repo.record(answer(session: 9));

    pacing = await repo.pacing(now: day);
    expect(pacing.hasNewMaterialToday, isTrue);
    expect(pacing.successfulReviewsSinceLatestNew, 3);
    expect(pacing.completedAlphabetCheckpoints, {7});
    expect(pacing.canIntroduceNewMaterial(repoRules), isTrue);

    final restarted = ProgressRepository(
      database: db,
      letterFormIds: const {'ba.isolated'},
      baseLetterIds: const {'ba.isolated', 'ta.isolated'},
    );
    expect((await restarted.pacing(now: day)).completedAlphabetCheckpoints, {
      7,
    });
    expect(
      (await restarted.pacing(
        now: day.add(const Duration(days: 1)),
      )).hasNewMaterialToday,
      isFalse,
    );
  });
}

const repoRules = LearningRules();
