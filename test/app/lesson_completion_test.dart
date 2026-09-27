import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:drift/native.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';

/// Урок считается пройденным только когда человек дошёл до конца сессии.
/// Открыть и выйти — не прохождение.
/// Фигуры для обводки читаем с диска, а не через rootBundle: в тестах он
/// отвечает только первому тесту файла, а остальные вешает.
Future<TracingShape> shapeFromDisk(String asset) async {
  final path = asset.contains('/')
      ? 'assets/svg/$asset.svg'
      : 'assets/svg/alphabet/$asset.svg';
  return TracingShapeSvg.parse(File(path).readAsStringSync(), id: asset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressDatabase db;
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  setUp(() {
    mockPlatformPlugins();
    db = ProgressDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    Get.reset();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    // Нажатие запускает анимацию на ~200 мс. Без прокрутки фейковых часов
    // тест уходит с висящим таймером и падает на проверке инвариантов.
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<LessonController> open(WidgetTester tester) async {
    Get.put(
      LessonController(
        shapeLoader: shapeFromDisk,
        database: db,
        curriculum: curriculum,
        topicId: 'm.first',
        audio: LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    return Get.find<LessonController>();
  }

  /// Отвечает на текущее задание верно.
  ///
  /// Обводку здесь не рисуем и голос не пишем: холст и сервер проверены
  /// отдельно, а этим тестам важна только бухгалтерия прохождения. Письмо
  /// и «назови букву» закрываем через контроллер — ровно так же, как это
  /// делают холст, узнав букву, и сервер, услышав её.
  Future<void> answerOne(WidgetTester tester, LessonController c) async {
    while (c.stage.value == LessonStage.intro) {
      await tester.runAsync(c.nextIntro);
      await settle(tester);
    }
    final ex = c.current!;
    if (c.isTracingTask || c.isSayNameTask) {
      await c.submit(directOutcome: true);
      if (c.wasCorrect.value) await c.submit();
    } else {
      c.select(ex.isChoice ? ex.answerIndex : 0);
      await c.submit();
      if (c.wasCorrect.value) await c.submit();
    }
    await settle(tester);
  }

  Future<void> answerAll(WidgetTester tester, LessonController c) async {
    while (c.stage.value != LessonStage.finished) {
      await answerOne(tester, c);
    }
  }

  testWidgets('открыть и выйти — урок не пройден', (tester) async {
    await open(tester);
    expect(await db.readCompletions(), isEmpty);
  });

  testWidgets('пройти только объяснения — урок не пройден', (tester) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    expect(c.stage.value, LessonStage.exercise);
    expect(await db.readCompletions(), isEmpty);
  });

  testWidgets('бросить на середине заданий — урок не пройден', (tester) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    for (var i = 0; i < 3; i++) {
      await answerOne(tester, c);
    }
    expect(c.stage.value, LessonStage.intro);
    expect(await db.readCompletions(), isEmpty);
  });

  testWidgets('дойти до конца сессии — урок пройден', (tester) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    await answerAll(tester, c);

    final completions = await db.readCompletions();
    expect(completions.map((e) => e.topicId), ['m.first']);
    expect(completions.single.byTest, isFalse);
  });

  // Последняя карточка обводки остаётся в дереве, пока итог занятия
  // сохраняется. Она не должна заново читать уже очищенное текущее задание.
  testWidgets('последняя обводка без ошибки переходит к итогу', (tester) async {
    await db.close();
    final delayedDatabase = _DelayedFinishDatabase();
    db = delayedDatabase;
    addTearDown(delayedDatabase.unblock);
    final harakaCurriculum = CurriculumLoader.parse(
      File('assets/curriculum/stage3.json').readAsStringSync(),
    );
    const atomId = 'haraka.fatha';
    const plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: [],
      reviewAtoms: [atomId],
      reviewCounts: {atomId: 1},
      reason: 'проверка завершения после обводки',
    );
    Get.put(
      LessonController(
        database: delayedDatabase,
        curriculum: harakaCurriculum,
        plan: plan,
        rules: const LearningRules(
          tasksPerSession: 1,
          reviewPerSession: 0,
          requirePronunciation: false,
        ),
        shapeLoader: shapeFromDisk,
        audio: _SilentAudio(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    final controller = Get.find<LessonController>();
    expect(controller.current?.mode, ExerciseMode.trace);

    await controller.submit(directOutcome: true);
    await settle(tester);
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => delayedDatabase.finishStarted.future.timeout(
        const Duration(seconds: 2),
      ),
    );
    await tester.pump();

    expect(controller.current, isNull);
    expect(tester.takeException(), isNull);

    delayedDatabase.allowFinish.complete();
    await settle(tester);
    expect(controller.stage.value, LessonStage.finished);
  });

  testWidgets('ошибки не мешают засчитать урок', (tester) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }

    // Три ответа мимо: отметка о прохождении от них не зависит.
    var wrongs = 0;
    while (c.stage.value != LessonStage.finished) {
      if (c.stage.value == LessonStage.intro) {
        await tester.runAsync(c.nextIntro);
        await settle(tester);
        continue;
      }
      final ex = c.current!;
      final wrongTurn = wrongs < 3 && ex.isChoice && !c.wasWrong.value;
      c.select(
        wrongTurn
            ? (ex.answerIndex + 1) % ex.options.length
            : (ex.isChoice ? ex.answerIndex : 0),
      );
      if (wrongTurn) wrongs++;
      await c.submit();
      if (c.wasCorrect.value) await c.submit();
      await settle(tester);
    }

    expect(wrongs, 3);
    expect(c.stage.value, LessonStage.finished);
    expect((await db.readCompletions()).map((e) => e.topicId), ['m.first']);
  });

  testWidgets('возврат к пройденному уроку показывает все объяснения', (
    tester,
  ) async {
    // Проходим урок целиком.
    final first = await open(tester);
    while (first.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    await answerAll(tester, first);
    expect((await db.readCompletions()).map((e) => e.topicId), ['m.first']);

    // Заходим снова: объяснения должны быть те же, а не только понятие.
    Get.delete<LessonController>();
    final again = await open(tester);
    expect(again.introAtoms.map((a) => a.id), [
      'concept.letter',
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ]);
  });

  testWidgets('повторение темы спрашивает и уже освоенные буквы', (
    tester,
  ) async {
    final first = await open(tester);
    while (first.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    await answerAll(tester, first);

    Get.delete<LessonController>();
    final again = await open(tester);
    // Во втором заходе идём через контроллер: дерево виджетов переиспользуется
    // между pumpWidget, и искать кнопку по подписи здесь ненадёжно.
    while (again.stage.value == LessonStage.intro) {
      await again.nextIntro();
      await settle(tester);
    }

    // Возврат к теме — это повторение всей темы, а не добор недоученного.
    expect(again.stage.value, LessonStage.exercise);
    final asked = <String>{};
    while (again.stage.value == LessonStage.exercise) {
      final ex = again.current!;
      asked.add(ex.atom.id);
      again.select(ex.isChoice ? ex.answerIndex : 0);
      await again.submit();
      await settle(tester);
    }
    expect(asked.length, greaterThan(1));
  });

  testWidgets('заглушка умеет засчитать и верный, и неверный ответ', (
    tester,
  ) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await c.nextIntro();
      await settle(tester);
    }

    // Ищем задание без выбора — у него исход задаёт кнопка.
    while (c.stage.value == LessonStage.exercise && c.current!.isChoice) {
      final ex = c.current!;
      c.select(ex.answerIndex);
      await c.submit();
      await settle(tester);
    }
    if (c.stage.value != LessonStage.exercise) return;

    final atomId = c.current!.atom.id;
    await c.submitStub(correct: false);
    await settle(tester);
    expect(c.wasWrong.value, isTrue);

    final log = (await db.readAll()).whereType<ProgressEvent>().where(
      (e) => e.atomId == atomId,
    );
    expect(log.last.correct, isFalse);

    await c.submit();
    await settle(tester);
    await c.submitStub(correct: true);
    await settle(tester);

    final after = (await db.readAll()).whereType<ProgressEvent>().where(
      (e) => e.atomId == atomId,
    );
    expect(after.last.correct, isTrue);
  });

  testWidgets('пропуск не пишет ответ в лог', (tester) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await c.nextIntro();
      await settle(tester);
    }

    final before = (await db.readAll()).whereType<ProgressEvent>().length;

    await c.skipExercise();
    await settle(tester);

    // Пропуск — отладочный ход: атом не двигается ни вперёд, ни назад.
    final after = (await db.readAll()).whereType<ProgressEvent>().toList();
    expect(after, hasLength(before));
    expect(c.stage.value, LessonStage.intro);
    expect(c.introAtom!.id, 'ba.isolated');
  });

  testWidgets('пропустив все задания, доходим до итога', (tester) async {
    final c = await open(tester);
    while (c.stage.value == LessonStage.intro) {
      await c.nextIntro();
      await settle(tester);
    }
    while (c.stage.value != LessonStage.finished) {
      if (c.stage.value == LessonStage.intro) {
        await tester.runAsync(c.nextIntro);
      } else {
        await c.skipExercise();
      }
      await settle(tester);
    }
    expect(c.stage.value, LessonStage.finished);
  });
}

class _DelayedFinishDatabase extends ProgressDatabase {
  _DelayedFinishDatabase() : super(NativeDatabase.memory());

  final finishStarted = Completer<void>();
  final allowFinish = Completer<void>();

  void unblock() {
    if (!allowFinish.isCompleted) allowFinish.complete();
  }

  @override
  Future<void> finishSession({
    required int sessionId,
    required DateTime at,
    required LessonPurpose purpose,
    required int exerciseCount,
    required int firstTryCorrect,
    int? checkpointLetters,
  }) async {
    finishStarted.complete();
    await allowFinish.future;
    await super.finishSession(
      sessionId: sessionId,
      at: at,
      purpose: purpose,
      exerciseCount: exerciseCount,
      firstTryCorrect: firstTryCorrect,
      checkpointLetters: checkpointLetters,
    );
  }
}

class _SilentAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  @override
  Future<void> dispose() async => track.dispose();

  @override
  Future<void> playAsset(String? asset) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> toggleAsset(String? asset) async {}
}
