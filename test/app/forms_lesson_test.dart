import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Второй урок раньше закрывался после конечных форм. Проверяем настоящий
/// контроллер с базой: все десять форм объяснены и спрошены за один сеанс,
/// а варианты ответа не показывают незнакомые формы без объяснений.
/// Экран и плагины здесь не нужны: проверяется порядок обучения и запись
/// прогресса, а не рисование и запись звука.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultStageAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final formsTopic = curriculum.topics.firstWhere((t) => t.id == 'm.forms');
  final formIds = formsTopic.counterOf.where((id) => id != 'concept.forms');
  late ProgressDatabase database;
  late ProgressRepository progress;

  setUp(() async {
    database = ProgressDatabase(NativeDatabase.memory());
    progress = ProgressRepository(database: database);
  });
  tearDown(() => database.close());

  Future<void> seedFirstLesson() async {
    await progress.recordAll([
      for (final id in curriculum.topics.first.counterOf)
        AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026)),
    ]);
    await progress.completeTopic('m.first', sessionId: 1);
  }

  Future<LessonController> open(String? topicId) async {
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      topicId: topicId,
      shapeLoader: (asset) async => TracingShapeSvg.parse(
        File('assets/svg/alphabet/$asset.svg').readAsStringSync(),
        id: asset,
      ),
    );
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) ready.complete();
    });
    controller.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    expect(controller.loadError.value, isNull);
    while (controller.stage.value == LessonStage.intro) {
      await controller.nextIntro();
    }
    return controller;
  }

  Future<void> readCards(LessonController controller) async {
    while (controller.card.value != null) {
      await controller.dismissCard();
    }
  }

  // Перенос голоса не должен пропускать объяснения, удваивать задания
  // или завершать урок после первой буквы. Проверяем и автоплан, и тему.
  for (final topicId in ['m.first', null]) {
    test('новые буквы произносятся сразу после знакомства: $topicId', () async {
      final controller = await open(topicId);
      addTearDown(controller.onClose);
      final letters = controller.introAtoms
          .where((a) => a.form == LetterForm.isolated)
          .toList();
      for (final (index, letter) in letters.indexed) {
        expect(controller.stage.value, LessonStage.exercise);
        expect(controller.current!.atom.id, letter.id);
        expect(controller.current!.mode, ExerciseMode.sayName);
        expect(controller.exerciseNumber, index + 1);
        expect(controller.totalExercises, 20);
        final introduced = (await database.readAll())
            .whereType<AtomIntroduced>()
            .map((e) => e.atomId);
        expect(introduced, contains(letter.id));
        for (final future in letters.skip(index + 1)) {
          expect(introduced, isNot(contains(future.id)));
        }
        await controller.answerCorrectly();
        if (index < letters.length - 1) {
          expect(controller.stage.value, LessonStage.intro);
          expect(controller.introAtom!.id, letters[index + 1].id);
          await controller.nextIntro();
        }
      }
      expect(await database.readCompletions(), isEmpty);
      var remaining = 0;
      while (controller.stage.value == LessonStage.exercise) {
        expect(++remaining, lessThanOrEqualTo(16));
        expect(controller.current!.mode, isNot(ExerciseMode.sayName));
        await controller.answerCorrectly();
      }
      expect(remaining, 16);
      expect(controller.stage.value, LessonStage.finished);
      expect(
        (await database.readAll()).whereType<ProgressEvent>(),
        hasLength(20),
      );
    });
  }

  // Ошибка оставляет человека на произношении, пропуск возвращает
  // к следующей карточке. Очередь повторов при этом должна сохраниться.
  test(
    'ошибка и пропуск произношения не теряют следующие объяснения',
    () async {
      final controller = await open('m.first');
      addTearDown(controller.onClose);
      final first = controller.current!;
      await controller.submit(directOutcome: false);
      expect(controller.current, same(first));
      expect(controller.stage.value, LessonStage.exercise);
      expect(controller.totalExercises, 21);
      await controller.submit(); // Закрыть разбор ошибки.
      expect(controller.current, same(first));
      await controller.answerCorrectly();
      expect(controller.stage.value, LessonStage.intro);
      expect(controller.introAtom!.id, 'ba.isolated');
      await controller.nextIntro();
      expect(controller.current!.atom.id, 'ba.isolated');
      expect(controller.current!.mode, ExerciseMode.sayName);
      final before = (await database.readAll())
          .whereType<ProgressEvent>()
          .length;
      await controller.skipExercise();
      expect(
        (await database.readAll()).whereType<ProgressEvent>(),
        hasLength(before),
      );
      expect(controller.stage.value, LessonStage.intro);
      expect(controller.introAtom!.id, 'ta.isolated');
      var steps = 0;
      var repeatedFirst = 0;
      while (controller.stage.value != LessonStage.finished) {
        expect(++steps, lessThan(30));
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
        } else {
          if (identical(controller.current, first)) repeatedFirst++;
          await controller.answerCorrectly();
        }
      }
      expect(repeatedFirst, 1);
      expect(controller.totalExercises, 21);
    },
  );

  test('второй урок обучает всем формам до открытия третьего', () async {
    await seedFirstLesson();
    final controller = await open('m.forms');
    addTearDown(controller.onClose);
    final shown = curriculum.topics.first.counterOf.toSet();
    final asked = <String>[];
    final positions = <LetterForm>[];
    const order = [LetterForm.finalForm, LetterForm.initial, LetterForm.medial];
    while (controller.stage.value == LessonStage.exercise) {
      expect(asked.length, lessThan(26), reason: 'урок должен завершиться');
      final exercise = controller.current!;
      while (controller.card.value != null) {
        final card = controller.card.value!;
        shown.add(card.id);
        if (card.form != null && formIds.contains(card.id)) {
          expect(
            order.indexOf(card.form!),
            lessThanOrEqualTo(order.indexOf(exercise.atom.form!)),
            reason: 'будущая позиция объясняется в своём блоке',
          );
        }
        await controller.dismissCard();
      }
      for (final atom in [
        exercise.atom,
        if (exercise.prompt case final prompt?) prompt,
        ...exercise.options,
      ]) {
        expect(
          shown,
          contains(atom.id),
          reason: '${atom.id} попала в задание до объяснения',
        );
      }
      asked.add(exercise.atom.id);
      if (formIds.contains(exercise.atom.id)) {
        positions.add(exercise.atom.form!);
      }
      final completed = await database.readCompletions();
      expect(completed.map((c) => c.topicId), isNot(contains('m.forms')));
      await controller.answerCorrectly();
    }
    expect(asked, hasLength(20));
    expect(asked.toSet(), containsAll(formIds));
    expect(shown, containsAll(formIds));
    expect(
      positions.map(order.indexOf),
      orderedEquals(positions.map(order.indexOf).toList()..sort()),
    );
    final log = await database.readAll();
    expect(
      log.whereType<AtomIntroduced>().map((e) => e.atomId).toSet(),
      containsAll(formIds),
    );
    expect(
      log.whereType<ProgressEvent>().map((e) => e.atomId).toSet(),
      containsAll(formIds),
    );
    await progress.recompute();
    final statuses = TopicBoard(curriculum).statuses(
      CurriculumContext(progress: await progress.progress(), formsByLetter: {}),
      completed: {
        for (final c in await database.readCompletions()) c.topicId: c.byTest,
      },
    );
    expect(
      statuses.firstWhere((s) => s.topic.id == 'm.jim').state,
      TopicState.available,
    );

    final next = await open('m.jim');
    addTearDown(next.onClose);
    while (next.stage.value != LessonStage.finished) {
      if (next.stage.value == LessonStage.intro) {
        await next.nextIntro();
        continue;
      }
      await readCards(next);
      await progress.recompute();
      final known = await progress.progress();
      final ex = next.current!;
      for (final a in [
        ex.atom,
        if (ex.prompt case final p?) p,
        ...ex.options,
      ]) {
        expect(
          known[a.id]?.state,
          isNot(anyOf(null, AtomState.fresh)),
          reason: 'третий урок спрашивает необъяснённую ${a.id}',
        );
      }
      await next.answerCorrectly();
    }
  });

  test(
    'повтор старого незавершённого урока добирает начальные и срединные',
    () async {
      await seedFirstLesson();
      await progress.recordAll([
        for (final id in [
          'concept.forms',
          'alif.finalForm',
          'ba.finalForm',
          'ta.finalForm',
          'tha.finalForm',
        ])
          AtomIntroduced(atomId: id, sessionId: 2, at: DateTime(2026)),
      ]);
      await progress.completeTopic('m.forms', sessionId: 2);
      final controller = await open('m.forms');
      addTearDown(controller.onClose);
      final asked = <String>{};
      while (controller.stage.value == LessonStage.exercise) {
        await readCards(controller);
        asked.add(controller.current!.atom.id);
        await controller.answerCorrectly();
      }
      expect(asked, containsAll(formIds));
      final log = await database.readAll();
      expect(
        log.whereType<AtomIntroduced>().map((e) => e.atomId).toSet(),
        containsAll(formIds),
      );
    },
  );

  // Новая тема, рост очереди повторения или уменьшение лимита не должны
  // незаметно выкинуть часть материала. Проходим весь реальный курс,
  // затем повторяем его: каждая форма объяснена и проверена в своём сеансе.
  test(
    'каждый урок курса покрывает весь свой материал при обоих входах',
    () async {
      final shownEver = <String>{};
      final byId = {for (final n in curriculum.nodes) n.atom.id: n.atom};
      for (var pass = 0; pass < 2; pass++) {
        for (final topic in curriculum.topics) {
          final controller = await open(topic.id);
          try {
            final shownHere = controller.introAtoms.map((a) => a.id).toSet();
            shownEver.addAll(shownHere);
            final asked = <String, List<ExerciseMode>>{};
            final logStart = (await database.readAll()).length;
            var count = 0;
            while (controller.stage.value != LessonStage.finished) {
              if (controller.stage.value == LessonStage.intro) {
                await controller.nextIntro();
                continue;
              }
              expect(++count, lessThanOrEqualTo(20), reason: topic.id);
              while (controller.card.value != null) {
                final id = controller.card.value!.id;
                shownHere.add(id);
                shownEver.add(id);
                await controller.dismissCard();
              }
              final ex = controller.current!;
              for (final atom in [
                ex.atom,
                if (ex.prompt case final p?) p,
                ...ex.options,
              ]) {
                if (atom.kind != AtomKind.letterForm) continue;
                expect(
                  shownEver,
                  contains(atom.id),
                  reason: '${topic.id}: ${atom.id} спрашивается до объяснения',
                );
              }
              (asked[ex.atom.id] ??= []).add(ex.mode);
              await controller.answerCorrectly();
            }
            for (final id in topic.counterOf) {
              final atom = byId[id]!;
              if (atom.kind == AtomKind.letterForm ||
                  atom.kind == AtomKind.concept) {
                expect(
                  shownHere,
                  contains(id),
                  reason: '${topic.id}, вход $pass',
                );
              }
              if (atom.kind == AtomKind.concept) continue;
              expect(
                asked.keys,
                contains(id),
                reason: '${topic.id}, вход $pass',
              );
              if (atom.form == LetterForm.isolated && atom.letterId != null) {
                expect(
                  asked[id],
                  containsAll([
                    ExerciseMode.trace,
                    ExerciseMode.traceFromMemory,
                    ExerciseMode.sayName,
                  ]),
                  reason: id,
                );
              }
            }
            final answers = (await database.readAll())
                .skip(logStart)
                .whereType<ProgressEvent>();
            expect(
              answers.map((e) => e.atomId).toSet(),
              containsAll(
                topic.counterOf.where(
                  (id) => byId[id]!.kind != AtomKind.concept,
                ),
              ),
              reason: 'Все задания ${topic.id} действительно получили ответы',
            );
            expect(
              (await database.readCompletions()).map((c) => c.topicId),
              contains(topic.id),
            );
          } finally {
            controller.onClose();
          }
        }
      }
    },
  );
}
