import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_learned_popup.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';

// Защищает порядок после ответа: награда открывается после результата,
// удерживает прежнее задание до закрытия и не повторяется при новом заходе.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  final alif = curriculum.baseLetters.firstWhere((a) => a.letterId == 'alif');
  final finalForm = curriculum.nodes
      .map((n) => n.atom)
      .firstWhere((a) => a.id == 'alif.finalForm');
  late ProgressDatabase db;

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
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('поп-ап показывает данные переданной буквы', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: LetterLearnedPopup(atom: alif)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('ا'), findsOneWidget);
    expect(find.textContaining('букву Алиф'), findsOneWidget);
    expect(find.text('ج'), findsNothing);
  });

  testWidgets('награда задерживает переход до закрытия', (tester) async {
    final at = DateTime(2026, 1, 1);
    await db.appendAll([
      for (final mode in [
        ExerciseMode.trace,
        ExerciseMode.traceFromMemory,
        ExerciseMode.sayName,
      ])
        ProgressEvent(
          atomId: alif.id,
          sessionId: 1,
          at: at,
          mode: mode,
          correct: true,
          attempt: 1,
          fastEnough: true,
        ),
    ]);
    final plan = LessonPlan(
      template: LessonTemplate.newLetter,
      newAtoms: [finalForm],
      reviewAtoms: const [],
      reason: 'проверка награды',
    );
    final controller = Get.put(
      LessonController(
        database: db,
        curriculum: curriculum,
        plan: plan,
        audio: _SilentAudio(),
        shapeLoader: (asset) async => TracingShapeSvg.parse(
          File('assets/svg/alphabet/$asset.svg').readAsStringSync(),
          id: asset,
        ),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    while (controller.stage.value == LessonStage.intro) {
      await controller.nextIntro();
      await settle(tester);
    }

    for (
      var i = 0;
      i < 10 && find.byType(LetterLearnedPopup).evaluate().isEmpty;
      i++
    ) {
      final exercise = controller.current!;
      if (exercise.isChoice) controller.select(exercise.answerIndex);
      await controller.submit(directOutcome: true);
      await settle(tester);
      expect(find.byType(LetterLearnedPopup), findsNothing);
      await tester.tap(find.text('Продолжить'));
      await settle(tester);
    }

    expect(find.byType(LetterLearnedPopup), findsOneWidget);
    expect(find.textContaining('букву Алиф'), findsOneWidget);
    final rewardedExercise = controller.current;
    expect(controller.wasCorrect.value, isTrue);
    expect(controller.stage.value, LessonStage.exercise);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.byType(LetterLearnedPopup), findsOneWidget);
    expect(controller.current, same(rewardedExercise));
    expect(controller.wasCorrect.value, isTrue);
    expect((await db.readAll()).whereType<LetterLearned>(), hasLength(1));
    final reopenedProgress = ProgressRepository(
      database: db,
      letterFormIds: curriculum.letterFormIds,
      baseLetterIds: curriculum.baseLetterIds,
    );
    expect(await reopenedProgress.learnedLetterIds(), contains('alif'));
    await tester.tap(find.text('Закрыть').last);
    await settle(tester);
    expect(find.byType(LetterLearnedPopup), findsNothing);
    expect(controller.wasCorrect.value, isFalse);
    expect(
      controller.stage.value == LessonStage.finished ||
          !identical(controller.current, rewardedExercise),
      isTrue,
    );
  });
}

class _SilentAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  @override
  Future<void> playAsset(String? asset) async {}

  @override
  Future<void> toggleAsset(String? asset) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => track.dispose();
}
