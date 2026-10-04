import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_exercise_presentation.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/form_sequence_evaluation.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:collection/collection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сборка проверяет сразу четыре формы. Этот тест защищает обе части
/// правила: старые записи очереди сворачиваются в одно упражнение, а экран
/// сохраняет отдельный результат каждой форме, а не только основной.
/// В сборке разных букв два одинаковых знака проверяются по слотам: ошибка
/// третьего слога не должна сбрасывать первые два или записываться самому знаку.
/// В огласовках короткая сборка пишет ровно два результата и показывает
/// правильный счёт ошибки; исправление и добор не добавляют третью сборку.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  final baForms = curriculum.nodes
      .map((node) => node.atom)
      .where((atom) => atom.letterId == 'ba' && atom.form != null)
      .toList();
  late ProgressDatabase database;
  late ProgressRepository progress;

  setUp(() {
    database = ProgressDatabase(NativeDatabase.memory());
    progress = ProgressRepository(
      database: database,
      letterFormIds: curriculum.letterFormIds,
    );
  });
  tearDown(() => database.close());

  test('повторяемые огласовки дают отдельный результат каждому слогу', () {
    const expected = ['haraka.fatha', 'haraka.fatha', 'haraka.kasra'];
    const syllables = ['vowel.ba.fatha', 'vowel.ta.fatha', 'vowel.mim.kasra'];
    final fatha = HarakaSyllables.marks[0];
    final kasra = HarakaSyllables.marks[1];
    final wrong = FormSequenceEvaluation.evaluate(
      options: HarakaSyllables.marks,
      placed: [fatha, fatha, fatha],
      expectedAtomIds: expected,
      resultAtomIds: syllables,
    );
    expect(wrong.correct, isFalse);
    expect(wrong.atomResults, {
      syllables[0]: true,
      syllables[1]: true,
      syllables[2]: false,
    });
    expect(wrong.slotResults, [true, true, false]);
    expect(wrong.initialPlaced, [fatha, fatha, null]);
    final correct = FormSequenceEvaluation.evaluate(
      options: HarakaSyllables.marks,
      placed: [fatha, fatha, kasra],
      expectedAtomIds: expected,
      resultAtomIds: syllables,
    );
    expect(correct.correct, isTrue);
    expect(correct.atomResults.values, everyElement(isTrue));
    expect(HarakaSyllables.applyMark('أ', kasra), 'إِ');
  });

  Future<LessonController> openOldRepeat() async {
    final at = DateTime(2026, 9, 10);
    await progress.recordAll([
      for (final atom in baForms)
        KnowledgeConfirmed(atomId: atom.id, sessionId: 1, at: at),
    ]);
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      plan: LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: const [],
        spacedReview: baForms.map((atom) => atom.id).toList(),
        reason: 'проверка семейного повтора',
      ),
      shapeLoader: (_) async =>
          throw UnsupportedError('Холст в сборке не используется'),
    );
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) {
        ready.complete();
      }
    });
    controller.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    addTearDown(controller.onClose);
    expect(controller.loadError.value, isNull);
    expect(controller.totalExercises, 1);
    expect(controller.current!.mode, ExerciseMode.positionToForm);
    return controller;
  }

  List<Atom> correctOrder(LessonController controller) => [
    for (final form in LetterForm.values)
      controller.current!.options.firstWhere((atom) => atom.form == form),
  ];

  test('верная сборка сохраняет четыре успешных ответа', () async {
    final controller = await openOldRepeat();

    await controller.submitFormSequence(correctOrder(controller));

    final events = (await database.readAll())
        .whereType<ProgressEvent>()
        .where((event) => event.mode == ExerciseMode.positionToForm)
        .toList();
    expect(events, hasLength(4));
    expect(events.map((event) => event.atomId).toSet(), {
      for (final atom in baForms) atom.id,
    });
    expect(events.every((event) => event.correct), isTrue);
  });

  test('ошибка отмечает только перепутанные формы', () async {
    final controller = await openOldRepeat();
    final placed = correctOrder(controller);
    final swapped = [...placed]..swap(1, 2);

    await controller.submitFormSequence(swapped);

    final results = {
      for (final event
          in (await database.readAll()).whereType<ProgressEvent>().where(
            (event) => event.mode == ExerciseMode.positionToForm,
          ))
        event.atomId: event.correct,
    };
    expect(results[placed[0].id], isTrue);
    expect(results[placed[1].id], isFalse);
    expect(results[placed[2].id], isFalse);
    expect(results[placed[3].id], isTrue);
    expect(controller.formSequenceCorrectCount, 2);
    expect(controller.formSequenceSlotResults, [true, false, false, true]);
    expect(controller.formSequenceInitialPlaced, [
      placed[0],
      null,
      null,
      placed[3],
    ]);
    expect(controller.revealFormSequenceAnswer, isFalse);
  });

  test('третья ошибка включает краткий показ правильного порядка', () async {
    final controller = await openOldRepeat();
    final placed = correctOrder(controller);
    final swapped = [...placed]..swap(1, 2);

    for (var mistake = 1; mistake <= 3; mistake++) {
      await controller.submitFormSequence(swapped);
      expect(
        controller.revealFormSequenceAnswer,
        mistake == 3,
        reason: 'подсказка на ошибке $mistake',
      );
      if (mistake < 3) await controller.submit();
    }
  });

  test(
    'двухформенное повторение в огласовках сохраняет ответ и доступ',
    () async {
      final course = CurriculumLoader.merge([
        for (final stage in [1, 2, 3])
          CurriculumLoader.parse(
            File('assets/curriculum/stage$stage.json').readAsStringSync(),
          ),
      ]);
      final at = DateTime(2026, 9, 20);
      final oldIds = course.topics
          .where((topic) => topic.stage == 1)
          .expand((topic) => topic.counterOf)
          .toSet();
      await progress.recordAll([
        AtomIntroduced(atomId: 'concept.haraka', sessionId: 10, at: at),
        for (final node in course.nodes)
          if (oldIds.contains(node.atom.id))
            if (node.atom.kind == AtomKind.concept)
              AtomIntroduced(atomId: node.atom.id, sessionId: 1, at: at)
            else
              KnowledgeConfirmed(
                atomId: node.atom.id,
                sessionId: node.atom.letterId == 'alif'
                    ? 1
                    : node.atom.letterId == 'dal'
                    ? 2
                    : 10,
                at: at,
              ),
      ]);
      final ctx = CurriculumContext(
        progress: await progress.progress(),
        formsByLetter: course.formsByLetter,
      );
      final topic = course.topics.firstWhere(
        (topic) => topic.id == 'm.haraka.signs',
      );
      final controller = LessonController(
        database: database,
        curriculum: course,
        plan: TopicBoard(course).planFor(topic, ctx, sessionId: 11),
        continuePlanning: true,
        shapeLoader: (_) async =>
            throw UnsupportedError('Холст не нужен для проверки журнала'),
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
      expect(controller.loadError.value, isNull);
      var forms = 0;
      var steps = 0;
      while (controller.stage.value != LessonStage.finished) {
        expect(++steps, lessThan(100));
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
          continue;
        }
        while (controller.card.value != null) {
          await controller.dismissCard();
        }
        final exercise = controller.current!;
        if (exercise.isFormMaintenance) {
          forms++;
          expect(exercise.options, hasLength(2));
          final order = exercise.options.sortedBy((atom) => atom.form!.index);
          if (forms == 1) {
            await controller.submitFormSequence([...order]..swap(0, 1));
            expect(controller.formSequenceSlotResults, [false, false]);
            expect(
              LessonExercisePresentation.from(exercise).feedbackText(
                correct: false,
                answerLabel: '',
                formSequenceCorrectCount: 0,
              ),
              contains('из 2'),
            );
            await controller.submit();
          }
          await controller.submitFormSequence(order);
          await controller.submit();
        } else {
          await controller.answerCorrectly(advance: true);
        }
      }
      expect(forms, 2);
      expect(controller.totalExercises, lessThanOrEqualTo(20));
      final results = (await database.readAll())
          .whereType<ProgressEvent>()
          .where((event) => event.mode == ExerciseMode.positionToForm)
          .toList();
      expect(results, hasLength(6)); // Ошибка и исправление алифа, затем даль.
      expect(results.take(2).every((event) => !event.correct), isTrue);
      expect(results.skip(2).every((event) => event.correct), isTrue);
      await progress.recompute();
      final after = CurriculumContext(
        progress: await progress.progress(),
        formsByLetter: course.formsByLetter,
      );
      expect(
        course.topics
            .firstWhere((topic) => topic.id == 'm.haraka.intro')
            .requirement
            .isMet(after.accessContext),
        isTrue,
      );
      expect(LessonPlanner(curriculum: course).activeStage(after), 2);
      expect(
        TopicBoard(course)
            .statuses(after)
            .firstWhere((status) => status.topic.id == 'm.haraka.group1')
            .state,
        isNot(TopicState.locked),
        reason: ['haraka.fatha', 'haraka.kasra', 'haraka.damma']
            .map(
              (id) =>
                  '$id: ${after.progress[id]?.state}, '
                  '${after.progress[id]?.cleanStreak}, ${after.progress[id]?.successfulModes}',
            )
            .join('; '),
      );
    },
  );
}
