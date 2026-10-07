// Проверяет новые сборки в настоящем уроке: автоматическая проверка,
// раздельный журнал формы/огласовки, сохранение верных частей при исправлении.
// Быстрые повторные нажатия и старые плитки не заполняют соседние места;
// отладочное завершение проходит тем же путём, не оставляя урок зависшим.
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/connection_build_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/word_build_exercise.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/word_build_question.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';
import '../helpers/text_asset_bundle.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  late ProgressDatabase database;
  late LessonController controller;
  late _Audio audio;

  setUp(() {
    mockPlatformPlugins();
    database = ProgressDatabase(NativeDatabase.memory());
    audio = _Audio();
  });
  tearDown(() async {
    Get.reset();
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 5; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> mount(WidgetTester tester, ExerciseMode mode) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final now = DateTime(2026, 10, 6);
      await database.appendAll([
        for (final topic in curriculum.topics.takeWhile(
          (topic) => topic.id != 'm.haraka.group1',
        ))
          for (final id in topic.counterOf)
            if (byId[id]!.kind == AtomKind.concept)
              AtomIntroduced(atomId: id, sessionId: 1, at: now)
            else
              KnowledgeConfirmed(atomId: id, sessionId: 1, at: now),
      ]);
      controller = LessonController(
        rules: const LearningRules(requirePronunciation: false),
        database: database,
        curriculum: curriculum,
        topicId: 'm.haraka.group1',
        audio: audio,
        explanationBundle: TextAssetBundle.forCurriculum(curriculum),
        shapeLoader: (asset) async => TracingShapeSvg.parse(
          File(
            'assets/svg/${asset.contains('/') ? asset : 'alphabet/$asset'}.svg',
          ).readAsStringSync(),
          id: asset,
        ),
      );
      final ready = controller.stage.stream.firstWhere(
        (stage) => stage != LessonStage.loading,
      );
      Get.put(controller);
      await ready.timeout(const Duration(seconds: 5));
      expect(controller.loadError.value, isNull);
      for (var step = 0; step < 60; step++) {
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
        } else if (controller.card.value != null) {
          await controller.dismissCard();
        } else if (controller.current?.mode == mode) {
          break;
        } else {
          expect(controller.stage.value, LessonStage.exercise);
          await controller.answerCorrectly(advance: true);
        }
      }
      expect(controller.current!.mode, mode);
    });
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    expect(find.text('Ответить'), findsNothing);
    expect(find.text('Ошибиться'), findsNothing);
  }

  Future<List<ProgressEvent>> events(
    WidgetTester tester,
    ExerciseMode mode,
  ) async => (await tester.runAsync(
    database.readAll,
  ))!.whereType<ProgressEvent>().where((event) => event.mode == mode).toList();

  Future<void> retry(WidgetTester tester) async {
    final button = find.text('Попробовать ещё раз');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  testWidgets('пропуск оценивает форму отдельно и исправляет только её', (
    tester,
  ) async {
    const mode = ExerciseMode.connectionBuild;
    await mount(tester, mode);
    final exercise = controller.current!;
    final question = exercise.connectionBuildQuestion!;
    final widget = tester.widget<ConnectionBuildExercise>(
      find.byType(ConnectionBuildExercise),
    );
    widget.onFormSelected(
      question.formOptions
          .firstWhere((form) => form.id != question.expectedFormId)
          .id,
    );
    await settle(tester);
    expect(audio.played.last, question.audioAsset);
    final withMarks = tester.widget<ConnectionBuildExercise>(
      find.byType(ConnectionBuildExercise),
    );
    withMarks.onMarkSelected(question.expectedMarkId);
    withMarks.onMarkSelected(question.expectedMarkId);
    await settle(tester);
    expect(controller.wasWrong.value, isTrue);
    final log = await events(tester, mode);
    expect(log, hasLength(2));
    expect(
      log
          .singleWhere((event) => event.atomId == question.missingPart.form.id)
          .correct,
      isFalse,
    );
    expect(
      log
          .singleWhere(
            (event) => event.atomId == question.missingPart.harakaAtom.id,
          )
          .correct,
      isTrue,
    );
    await retry(tester);
    expect(controller.connectedBuildAnswer!.formIds.single, isNull);
    expect(
      controller.connectedBuildAnswer!.markIds.single,
      question.expectedMarkId,
    );
    withMarks.onMarkSelected('haraka.damma');
    expect(
      controller.connectedBuildAnswer!.markIds.single,
      question.expectedMarkId,
    );
    final retried = tester.widget<ConnectionBuildExercise>(
      find.byType(ConnectionBuildExercise),
    );
    retried.onFormSelected(question.expectedFormId);
    await settle(tester);
    expect(controller.wasCorrect.value, isTrue);
    expect(
      (await events(tester, mode))
          .skip(2)
          .every(
            (event) => event.correct && event.attempt == 2 && !event.isClean,
          ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'слово проходит два этапа и сохраняет верные части после ошибки',
    (tester) async {
      const mode = ExerciseMode.wordBuild;
      await mount(tester, mode);
      final exercise = controller.current!;
      final question = exercise.wordBuildQuestion!;
      WordBuildExercise state() =>
          tester.widget<WordBuildExercise>(find.byType(WordBuildExercise));
      final first = state();
      final wrongForm = question.steps.first.formOptions
          .firstWhere((form) => form.id != question.steps.first.expectedFormId)
          .id;
      first.onFormSelected(wrongForm);
      first.onFormSelected(wrongForm);
      await settle(tester);
      expect(controller.connectedBuildAnswer!.activeIndex, 1);
      for (var index = 1; index < question.steps.length; index++) {
        state().onFormSelected(question.steps[index].expectedFormId);
        await settle(tester);
      }
      expect(controller.connectedBuildAnswer!.phase, WordBuildPhase.marks);
      expect(audio.played.last, question.audioAsset);
      for (var index = 0; index < question.steps.length; index++) {
        state().onMarkSelected(
          index == 1 ? 'haraka.damma' : question.steps[index].expectedMarkId,
        );
        await settle(tester);
      }
      expect(controller.wasWrong.value, isTrue);
      final log = await events(tester, mode);
      expect(log, hasLength(exercise.resultAtoms.length));
      expect(
        log
            .singleWhere(
              (event) => event.atomId == question.steps.first.part.form.id,
            )
            .correct,
        isFalse,
      );
      expect(
        log
            .singleWhere(
              (event) =>
                  event.atomId == question.steps.first.part.harakaAtom.id,
            )
            .correct,
        isTrue,
      );
      expect(
        log
            .singleWhere(
              (event) => event.atomId == question.steps[1].part.form.id,
            )
            .correct,
        isTrue,
      );
      expect(
        log
            .singleWhere(
              (event) => event.atomId == question.steps[1].part.harakaAtom.id,
            )
            .correct,
        isFalse,
      );
      await retry(tester);
      final answer = controller.connectedBuildAnswer!;
      expect(answer.formIds.first, isNull);
      expect(answer.formIds[1], question.steps[1].expectedFormId);
      expect(answer.markIds.first, question.steps.first.expectedMarkId);
      expect(answer.markIds[1], isNull);
      first.onFormSelected(wrongForm);
      expect(answer.formIds.first, isNull);
      state().onFormSelected(question.steps.first.expectedFormId);
      await settle(tester);
      expect(answer.phase, WordBuildPhase.marks);
      expect(answer.activeIndex, 1);
      state().onMarkSelected(question.steps[1].expectedMarkId);
      await settle(tester);
      expect(controller.wasCorrect.value, isTrue);
      final corrected = (await events(
        tester,
        mode,
      )).skip(exercise.resultAtoms.length);
      expect(
        corrected.every(
          (event) => event.correct && !event.isClean && event.attempt == 2,
        ),
        isTrue,
      );
      await tester.runAsync(controller.submit);
      await tester.runAsync(controller.finishLessonCorrectly);
      expect(controller.stage.value, LessonStage.finished);
      final all = (await tester.runAsync(
        database.readAll,
      ))!.whereType<ProgressEvent>().toList();
      expect(
        all
            .where((event) => event.mode.isWordPreparation)
            .map((event) => event.mode)
            .toSet(),
        {ExerciseMode.connectionBuild, mode},
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  final played = <String?>[];
  @override
  Future<void> playAsset(String? asset) async => played.add(asset);
  @override
  Future<void> toggleAsset(String? asset) async => played.add(asset);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => track.dispose();
}
