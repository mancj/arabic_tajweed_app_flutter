import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/data/voice_recorder.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Недоученная буква раньше превращала 2–3 вопроса во всю сессию.
/// Проверяем, что после закрытия пробела контроллер тут же
/// вводит открывшийся цельный блок и доводит общий бюджет до 20.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  late ProgressDatabase database;
  late ProgressRepository repository;

  setUp(() {
    database = ProgressDatabase(NativeDatabase.memory());
    repository = ProgressRepository(
      database: database,
      letterFormIds: curriculum.letterFormIds,
    );
  });

  tearDown(() => database.close());

  test(
    'после трёх заданий по «са» в той же сессии открываются формы',
    () async {
      final at = DateTime(2026, 9, 10);
      await repository.recordAll([
        AtomIntroduced(atomId: 'concept.letter', sessionId: 1, at: at),
        for (final id in ['alif.isolated', 'ba.isolated', 'ta.isolated'])
          KnowledgeConfirmed(atomId: id, sessionId: 1, at: at),
        AtomIntroduced(atomId: 'tha.isolated', sessionId: 1, at: at),
        for (final mode in const [
          ExerciseMode.trace,
          ExerciseMode.traceFromMemory,
          ExerciseMode.sayName,
        ])
          ProgressEvent(
            atomId: 'tha.isolated',
            sessionId: 1,
            at: at,
            mode: mode,
            correct: true,
            attempt: 1,
            fastEnough: true,
          ),
        ProgressEvent(
          atomId: 'tha.isolated',
          sessionId: 1,
          at: at,
          mode: ExerciseMode.soundToLetter,
          correct: false,
          attempt: 1,
          fastEnough: true,
        ),
      ]);
      final context = CurriculumContext(
        progress: await repository.progress(),
        formsByLetter: curriculum.formsByLetter,
      );
      final initial = LessonPlanner(
        curriculum: curriculum,
      ).plan(ctx: context, sessionId: 2, sessionsWithoutNew: 0);
      expect(initial.reviewCounts, {'tha.isolated': 3});

      final controller = LessonController(
        database: database,
        curriculum: curriculum,
        plan: initial,
        continuePlanning: true,
        shapeLoader: (_) async =>
            throw UnsupportedError('Холст тут не проверяем'),
      );
      addTearDown(controller.onClose);
      final ready = Completer<void>();
      final subscription = controller.stage.listen((stage) {
        if (stage != LessonStage.loading && !ready.isCompleted) {
          ready.complete();
        }
      });
      controller.onInit();
      await ready.future.timeout(const Duration(seconds: 5));
      await subscription.cancel();

      for (var i = 0; i < 3; i++) {
        expect(controller.current!.atom.id, 'tha.isolated');
        await controller.answerCorrectly(advance: true);
      }
      expect(controller.stage.value, LessonStage.intro);
      expect(controller.introAtom!.id, 'concept.forms');

      var answered = 3;
      while (controller.stage.value != LessonStage.finished) {
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
          continue;
        }
        while (controller.card.value != null) {
          await controller.dismissCard();
        }
        await controller.answerCorrectly(advance: true);
        answered++;
      }
      expect(answered, 20);
      expect(controller.totalExercises, 20);
      expect(
        controller.sessionIntroduced.map((atom) => atom.id),
        contains('concept.forms'),
      );
    },
  );

  // Пара новых букв раньше запускала следующий новый блок, лишь бы полоса
  // дошла до 20. Теперь после четырёх разных заданий на букву урок честно
  // заканчивается, если созревшего старого повтора в плане нет.
  test(
    'урок из двух новых букв может закончиться на восьми заданиях',
    () async {
      final at = DateTime(2026, 9, 10);
      await repository.recordAll([
        for (final id in ['alif.isolated', 'ba.isolated'])
          KnowledgeConfirmed(atomId: id, sessionId: 1, at: at),
      ]);
      final byId = {
        for (final node in curriculum.nodes) node.atom.id: node.atom,
      };
      final plan = LessonPlan(
        template: LessonTemplate.newLetter,
        newAtoms: [byId['sin.isolated']!, byId['shin.isolated']!],
        reviewAtoms: const [],
        reason: 'регрессия узкого блока',
      );
      final controller = LessonController(
        database: database,
        curriculum: curriculum,
        plan: plan,
        continuePlanning: true,
        shapeLoader: (_) async =>
            throw UnsupportedError('Холст тут не проверяем'),
      );
      addTearDown(controller.onClose);
      final ready = Completer<void>();
      final subscription = controller.stage.listen((stage) {
        if (stage != LessonStage.loading && !ready.isCompleted) {
          ready.complete();
        }
      });
      controller.onInit();
      await ready.future.timeout(const Duration(seconds: 5));
      await subscription.cancel();

      var answered = 0;
      while (controller.stage.value != LessonStage.finished) {
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
          continue;
        }
        await controller.answerCorrectly(advance: true);
        answered++;
      }

      expect(answered, 8);
      expect(controller.totalExercises, 8);
      expect(controller.progress, 1);
      final answers = (await database.readAll()).whereType<ProgressEvent>();
      for (final id in ['sin.isolated', 'shin.isolated']) {
        final modes = answers
            .where((event) => event.atomId == id)
            .map((event) => event.mode);
        expect(modes, hasLength(4));
        expect(
          modes.where((mode) => mode == ExerciseMode.soundToLetter),
          hasLength(1),
        );
      }
    },
  );

  test('технический пропуск отключает произношение до конца сессии', () async {
    SharedPreferences.setMockInitialValues({});
    final pronunciationPreference = PronunciationPreference(
      SharedPreferenceManager(await SharedPreferences.getInstance()),
    );
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      continuePlanning: true,
      recorder: _DeniedRecorder(),
      pronunciationPreference: pronunciationPreference,
      shapeLoader: (_) async =>
          throw UnsupportedError('Холст тут не проверяем'),
    );
    addTearDown(controller.onClose);
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) {
        ready.complete();
      }
    });
    controller.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();

    await controller.nextIntro(); // Понятие алфавита.
    await controller.nextIntro(); // Алиф и первое произношение.
    expect(controller.current!.mode, ExerciseMode.sayName);
    await controller.startRecording();
    expect(controller.pronunciation.error.value, 'Нет доступа к микрофону');
    expect((await database.readAll()).whereType<ProgressEvent>(), isEmpty);

    await controller.skipExercise();
    expect(pronunciationPreference.isDisabled, isTrue);
    var seenExercises = 1;
    while (controller.stage.value != LessonStage.finished) {
      if (controller.stage.value == LessonStage.intro) {
        await controller.nextIntro();
        continue;
      }
      while (controller.card.value != null) {
        await controller.dismissCard();
      }
      expect(controller.current!.mode, isNot(ExerciseMode.sayName));
      await controller.answerCorrectly(advance: true);
      seenExercises++;
    }

    final answers = (await database.readAll()).whereType<ProgressEvent>();
    expect(seenExercises, 20);
    expect(answers.every((event) => event.correct), isTrue);
    expect(
      answers.map((event) => event.mode),
      isNot(contains(ExerciseMode.sayName)),
    );
  });

  // Допуск к новым буквам должен переживать перезапуск. Поэтому смешанное
  // занятие получает итог только после последнего задания, не при старте.
  test('завершённое смешанное занятие сохраняет честный итог', () async {
    final at = DateTime(2026, 9, 13);
    const ids = ['alif.isolated', 'ba.isolated', 'ta.isolated', 'tha.isolated'];
    await repository.recordAll([
      for (final id in ids)
        KnowledgeConfirmed(atomId: id, sessionId: 1, at: at),
    ]);
    const plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: [],
      reviewAtoms: ids,
      reviewCounts: {
        'alif.isolated': 2,
        'ba.isolated': 2,
        'ta.isolated': 2,
        'tha.isolated': 2,
      },
      purpose: LessonPurpose.mixedReview,
      reason: 'проверяем сохранение итога',
    );
    const rules = LearningRules(
      tasksPerSession: 8,
      reviewLessonMinExercises: 8,
      requirePronunciation: false,
    );
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      plan: plan,
      rules: rules,
      continuePlanning: true,
      shapeLoader: (_) async =>
          throw UnsupportedError('Холст тут не проверяем'),
    );
    addTearDown(controller.onClose);
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) {
        ready.complete();
      }
    });
    controller.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();

    expect(await database.readSessionSummaries(), isEmpty);
    while (controller.stage.value != LessonStage.finished) {
      await controller.answerCorrectly(advance: true);
    }

    final summary = (await database.readSessionSummaries()).single;
    expect(summary.purpose, LessonPurpose.mixedReview.name);
    expect(summary.exerciseCount, 8);
    expect(summary.firstTryCorrect, 8);
  });
}

class _DeniedRecorder extends VoiceRecorder {
  @override
  Future<bool> start() async => false;
}
