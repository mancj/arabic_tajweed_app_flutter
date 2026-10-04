// Сборка автоматически проверяется после последнего нужного выбора и
// сохраняет один результат слога даже при быстрых повторных нажатиях.
// После разбора верная часть остаётся, а выбор ошибочной части сразу проверяет
// исправление. Оно не становится чистым ответом; результат ждёт «Продолжить».
// При переходе к огласовкам исходный слог повторяется с начала, включая
// повторный выбор очищенной буквы; уже открытый второй шаг не повторяет звук.
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_build_exercise.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';
import '../helpers/text_asset_bundle.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final now = DateTime(2026, 10, 3);
      await database.appendAll([
        for (final topic in curriculum.topics.takeWhile(
          (t) => t.id != 'm.haraka.group1',
        ))
          for (final id in topic.counterOf)
            if (byId[id]!.kind == AtomKind.concept)
              AtomIntroduced(atomId: id, sessionId: 1, at: now)
            else
              KnowledgeConfirmed(atomId: id, sessionId: 1, at: now),
      ]);
      controller = LessonController(
        database: database,
        curriculum: curriculum,
        explanationBundle: TextAssetBundle.forCurriculum(curriculum),
        topicId: 'm.haraka.group1',
        audio: audio,
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
      var steps = 0;
      while (true) {
        expect(++steps, lessThanOrEqualTo(20));
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
          continue;
        }
        while (controller.card.value != null) {
          await controller.dismissCard();
        }
        if (controller.current?.mode == ExerciseMode.syllableBuild) break;
        await controller.answerCorrectly(advance: true);
      }
      while (controller.card.value != null) {
        await controller.dismissCard();
      }
    });
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    expect(find.byType(SyllableBuildExercise), findsOneWidget);
    expect(find.text('Ошибиться'), findsNothing);
  }

  Finder letter(String id) => find.byKey(ValueKey('syllable-build-letter-$id'));
  Finder mark(String id) => find.byKey(ValueKey('syllable-build-mark-$id'));
  Future<void> choose(WidgetTester tester, Finder choice) async {
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await settle(tester);
  }

  Future<List<ProgressEvent>> buildEvents(WidgetTester tester) async =>
      (await tester.runAsync(database.readAll))!
          .whereType<ProgressEvent>()
          .where((event) => event.mode == ExerciseMode.syllableBuild)
          .toList();

  for (final (letterWrong, markWrong, title) in [
    (true, false, 'Огласовка верная, буква отличается'),
    (false, true, 'Буква верная, огласовка отличается'),
    (true, true, 'Буква и огласовка отличаются'),
  ]) {
    testWidgets('автопроверка и исправление: $title', (tester) async {
      await mount(tester);
      final exercise = controller.current!;
      final question = exercise.syllableBuildQuestion!;
      final wrongLetter = question.letterOptions
          .firstWhere((a) => a.letterId != exercise.atom.letterId)
          .letterId!;
      final wrongMark = HarakaSyllables.marks
          .firstWhere((mark) => mark.id != question.expectedMarkId)
          .id;
      final selectedLetter = letterWrong
          ? wrongLetter
          : exercise.atom.letterId!;
      final selectedMark = markWrong ? wrongMark : question.expectedMarkId;
      final plays = audio.played.length;
      expect(audio.played.last, exercise.atom.audioAsset);
      expect(find.text('Проверить'), findsNothing);
      expect(controller.canSubmit, isFalse);
      await tester.runAsync(() => controller.submit());
      expect(await buildEvents(tester), isEmpty);
      await choose(tester, letter(wrongLetter));
      await choose(tester, letter(exercise.atom.letterId!));
      await choose(tester, letter(selectedLetter));
      expect(controller.canSubmit, isFalse);
      expect(await buildEvents(tester), isEmpty);
      expect(audio.played, hasLength(plays + 1));
      expect(audio.played.last, exercise.atom.audioAsset);
      expect(audio.toggled, isEmpty);

      await tester.ensureVisible(mark(selectedMark));
      await tester.tap(mark(selectedMark));
      // Ещё до следующего кадра и сохранения в базе ответ уже зафиксирован.
      controller.selectSyllableBuildLetter(
        letterWrong ? exercise.atom.letterId! : wrongLetter,
      );
      controller.selectSyllableBuildMark(
        markWrong ? question.expectedMarkId : wrongMark,
      );
      expect(controller.syllableBuildLetter.value, selectedLetter);
      expect(controller.syllableBuildMark.value, selectedMark);
      await settle(tester);
      expect(find.text(title), findsOneWidget);
      expect(find.text('Проверить'), findsNothing);
      final failed = await buildEvents(tester);
      expect(failed, hasLength(1));
      expect(failed.single.atomId, exercise.atom.id);
      expect(failed.single.correct, isFalse);
      expect(failed.single.attempt, 1);
      expect(audio.played, hasLength(plays + 1));

      await choose(tester, find.text('Попробовать ещё раз'));
      expect(
        controller.syllableBuildLetter.value,
        letterWrong ? isNull : exercise.atom.letterId,
      );
      expect(
        controller.syllableBuildMark.value,
        markWrong ? isNull : question.expectedMarkId,
      );
      if (letterWrong) {
        await choose(tester, letter(exercise.atom.letterId!));
      }
      if (markWrong) {
        if (letterWrong) {
          expect(await buildEvents(tester), hasLength(1));
        }
        await choose(tester, mark(question.expectedMarkId));
      }
      expect(audio.played, hasLength(plays + (letterWrong ? 2 : 1)));
      expect(audio.played.last, exercise.atom.audioAsset);
      expect(audio.toggled, isEmpty);
      expect(find.text('Слог собран правильно'), findsOneWidget);
      final corrected = await buildEvents(tester);
      expect(corrected, hasLength(2));
      expect(corrected.last.atomId, exercise.atom.id);
      expect(corrected.last.correct, isTrue);
      expect(corrected.last.attempt, 2);
      expect(corrected.last.isClean, isFalse);
      await choose(tester, find.text('Продолжить'));
      expect(controller.syllableBuildLetter.value, isNull);
      expect(controller.syllableBuildMark.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'верный выбор огласовки показывает результат и ждёт продолжения',
    (tester) async {
      await mount(tester);
      final exercise = controller.current!;
      final question = exercise.syllableBuildQuestion!;
      await choose(tester, letter(exercise.atom.letterId!));
      await choose(tester, mark(question.expectedMarkId));
      expect(find.text('Слог собран правильно'), findsOneWidget);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(find.text('Проверить'), findsNothing);
      final events = await buildEvents(tester);
      expect(events, hasLength(1));
      expect(events.single.atomId, exercise.atom.id);
      expect(events.single.correct, isTrue);
      expect(events.single.isClean, isTrue);
      await settle(tester);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(await buildEvents(tester), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('отладочный верный ответ проходит через режим сборки', (
    tester,
  ) async {
    await mount(tester);
    final exercise = controller.current!;
    await tester.runAsync(() => controller.answerCorrectly());
    await settle(tester);
    expect(find.text('Слог собран правильно'), findsOneWidget);
    final events = await buildEvents(tester);
    expect(events, hasLength(1));
    expect(events.single.atomId, exercise.atom.id);
    expect(events.single.isClean, isTrue);
    await choose(tester, find.text('Продолжить'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  final played = <String?>[];
  final toggled = <String?>[];
  @override
  Future<void> playAsset(String? asset) async => played.add(asset);
  @override
  Future<void> toggleAsset(String? asset) async => toggled.add(asset);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => track.dispose();
}
