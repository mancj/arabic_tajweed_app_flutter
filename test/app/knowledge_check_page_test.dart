import 'package:flutter/widgets.dart';
import 'dart:io';
import 'package:arabic_tajweed_app/app/pages/course/course_controller.dart';
import 'package:arabic_tajweed_app/app/pages/course/knowledge_check_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/answer_option.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/knowledge_check.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_audio_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../helpers/plugin_mocks.dart';

/// Ошибка в проверке не даёт зачёт, а подтверждённые элементы сохраняются
/// даже при неполном успехе. Далёкую тему можно открыть короткой проверкой:
/// старый вариант требовал до 186 ответов за один подход.
/// Звук должен запускаться сам для букв, как в обычном уроке.
void main() {
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  TestWidgetsFlutterBinding.ensureInitialized();
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('буква дважды проверяется на слух с автозвуком', (tester) async {
    final audio = _RecordingAudio();
    final c = Get.put(CourseController(database: db, curriculum: curriculum));
    await tester.runAsync(() async {
      while (c.loading.value) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpWidget(
      GetMaterialApp(
        home: KnowledgeCheckPage(
          controller: c,
          topic: curriculum.topics[1],
          audio: audio,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Начать проверку'));
    await settle(tester);
    while (find.text('Понятно').evaluate().isNotEmpty) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }
    final check =
        (tester.state(find.byType(KnowledgeCheckPage)) as dynamic).check
            as KnowledgeCheck;
    const source = LessonAudioSource();
    expect(check.questions.first.mode, ExerciseMode.soundToLetter);
    await tester.pump(const Duration(milliseconds: 400));
    expect(audio.played, contains(source.forAtom(check.questions.first.atom)));

    await tester.tap(
      find.byType(AnswerOption).at(check.questions.first.answerIndex),
    );
    await tester.pump();
    await tester.tap(find.text('Ответить'));
    await settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(
      find.text('Не удалось сохранить ответ. Попробуйте ещё раз.'),
      findsNothing,
    );
    expect((tester.state(find.byType(KnowledgeCheckPage)) as dynamic).index, 1);
    expect(check.questions[1].mode, ExerciseMode.soundToLetter);
    await tester.pump(const Duration(milliseconds: 400));
    expect(audio.played.last, source.forAtom(check.questions[1].atom));
    expect(find.text('Прослушать ещё раз'), findsNothing);
  });

  for (final missOne in [false, true]) {
    testWidgets('проверка сохраняет результат: ошибка=$missOne', (
      tester,
    ) async {
      final c = Get.put(CourseController(database: db, curriculum: curriculum));
      await tester.runAsync(() async {
        while (c.loading.value) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpWidget(
        GetMaterialApp(
          home: KnowledgeCheckPage(
            controller: c,
            topic: curriculum.topics[1],
            audio: _RecordingAudio(),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Начать проверку'));
      await settle(tester);
      while (find.text('Понятно').evaluate().isNotEmpty) {
        await tester.tap(find.text('Понятно'));
        await settle(tester);
      }
      final check =
          (tester.state(find.byType(KnowledgeCheckPage)) as dynamic).check
              as KnowledgeCheck;
      for (var i = 0; i < 8; i++) {
        final question = check.questions[i];
        final choice = find
            .byType(AnswerOption)
            .at(
              missOne && i == 0
                  ? (question.answerIndex + 1) % question.options.length
                  : question.answerIndex,
            );
        await Scrollable.ensureVisible(tester.element(choice), alignment: .5);
        await tester.pump();
        await tester.tap(choice);
        await tester.pump();
        await tester.tap(find.text('Ответить'));
        await settle(tester);
        if (i == 1) {
          expect(
            (await db.readAll()).whereType<KnowledgeConfirmed>().length,
            missOne ? 0 : 1,
          );
        }
      }
      final log = await db.readAll();
      expect(log.whereType<KnowledgeConfirmed>().length, missOne ? 3 : 4);
      expect(
        find.text(missOne ? 'Пока есть пробелы' : 'Тема открыта'),
        findsOneWidget,
      );
      expect(
        find.text(missOne ? 'Вернуться к теме' : 'Начать новую тему'),
        findsOneWidget,
      );
      expect(
        find.text(missOne ? 'Закрепить пробелы сейчас' : 'Не сейчас'),
        findsOneWidget,
      );
      expect(c.statuses[1].canPractice, !missOne);
      expect(tester.takeException(), isNull);
    });
  }

  for (final missOne in [false, true]) {
    testWidgets('далёкая тема: короткая проверка, ошибка=$missOne', (
      tester,
    ) async {
      final fullCourse = CurriculumLoader.merge([
        for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
      ]);
      final topic = fullCourse.topics.firstWhere(
        (t) => t.id == 'm.haraka.intro',
      );
      final c = Get.put(CourseController(database: db, curriculum: fullCourse));
      await tester.runAsync(() async {
        while (c.loading.value) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpWidget(
        GetMaterialApp(
          home: KnowledgeCheckPage(
            controller: c,
            topic: topic,
            audio: _RecordingAudio(),
          ),
        ),
      );
      await settle(tester);
      expect(find.textContaining('20 заданий'), findsOneWidget);
      await tester.tap(find.text('Начать проверку'));
      await settle(tester);
      while (find.text('Понятно').evaluate().isNotEmpty) {
        await tester.tap(find.text('Понятно'));
        await settle(tester);
      }
      final check =
          (tester.state(find.byType(KnowledgeCheckPage)) as dynamic).check
              as KnowledgeCheck;
      for (var i = 0; i < 20; i++) {
        final question = check.questions[i];
        final choice = find
            .byType(AnswerOption)
            .at(
              missOne && i == 0
                  ? (question.answerIndex + 1) % question.options.length
                  : question.answerIndex,
            );
        await Scrollable.ensureVisible(tester.element(choice), alignment: .5);
        await tester.pump();
        await tester.tap(choice);
        await tester.pump();
        await tester.tap(find.text('Ответить'));
        await settle(tester);
      }
      expect(
        find.text(missOne ? 'Пока есть пробелы' : 'Тема открыта'),
        findsOneWidget,
      );
      expect(
        find.text(missOne ? 'Вернуться к теме' : 'Начать новую тему'),
        findsOneWidget,
      );
      expect(
        c.statuses.firstWhere((s) => s.topic.id == topic.id).canPractice,
        !missOne,
      );
      expect(
        (await db.readAll()).whereType<KnowledgeConfirmed>().length,
        missOne ? 9 : greaterThan(80),
      );
      if (!missOne) {
        final targetIndex = fullCourse.topics.indexOf(topic);
        expect(
          c.statuses.take(targetIndex).every((status) => status.isDone),
          isTrue,
        );
        final next = await tester.runAsync(c.planFor);
        expect(next?.topicId, topic.id);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _RecordingAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  final played = <String>[];

  @override
  Future<void> playAsset(String? asset) async {
    if (asset == null) return;
    played.add(asset);
    track.value = const AudioTrack(isPlaying: true);
  }

  @override
  Future<void> toggleAsset(String? asset) => playAsset(asset);

  @override
  Future<void> stop() async => track.value = AudioTrack.silent;

  @override
  Future<void> dispose() async => track.dispose();
}
