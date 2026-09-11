import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:collection/collection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сборка проверяет сразу четыре формы. Этот тест защищает обе части
/// правила: старые записи очереди сворачиваются в одно упражнение, а экран
/// сохраняет отдельный результат каждой форме, а не только основной.
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
      if (stage != LessonStage.loading && !ready.isCompleted) ready.complete();
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
  });
}
