import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:drift/native.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';

/// Произношение идёт после карточки каждой новой буквы. Проверяем экран,
/// чтобы переходы intro/exercise и счётчик не отставали от контроллера.
/// Фигуры для обводки читаем с диска, а не через rootBundle: в тестах он
/// отвечает только первому тесту файла, а остальные вешает.
Future<TracingShape> shapeFromDisk(String asset) async => TracingShapeSvg.parse(
  File('assets/svg/alphabet/$asset.svg').readAsStringSync(),
  id: asset,
);

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

  testWidgets('после каждой новой буквы открывается её произношение', (
    tester,
  ) async {
    Get.put(
      LessonController(
        database: db,
        curriculum: curriculum,
        shapeLoader: shapeFromDisk,
        audio: LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);

    final controller = Get.find<LessonController>();
    expect(controller.introAtoms.map((a) => a.id), [
      'concept.letter',
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ]);

    // Сколько букв в алфавите — первое, что человек видит.
    expect(find.textContaining('28 букв'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    for (final (index, id) in [
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ].indexed) {
      expect(controller.stage.value, LessonStage.intro);
      expect(controller.introAtom!.id, id);
      await tester.tap(find.text('Понятно'));
      await settle(tester);
      expect(controller.current!.atom.id, id);
      expect(controller.current!.mode, ExerciseMode.sayName);
      expect(find.text('Назовите эту букву вслух'), findsOneWidget);
      expect(find.text('№ ${index + 1} из 20'), findsOneWidget);
      await tester.runAsync(() => controller.submit(directOutcome: true));
      await settle(tester);
      await tester.tap(find.text('Продолжить'));
      await settle(tester);
    }
    expect(controller.stage.value, LessonStage.exercise);
    expect(controller.current!.mode, isNot(ExerciseMode.sayName));
    expect(find.text('№ 5 из 20'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });

  // Автоматическое закрепление не должно превращаться в повтор всех
  // объяснений лишь потому, что у плана указан id темы.
  testWidgets('один пропущенный режим открывается сразу без карточек темы', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.appendAll([
        for (final id in curriculum.topics.first.counterOf)
          if (id.startsWith('concept.'))
            AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026))
          else if (id != 'ba.isolated')
            KnowledgeConfirmed(atomId: id, sessionId: 1, at: DateTime(2026)),
        for (final mode in [
          ExerciseMode.trace,
          ExerciseMode.traceFromMemory,
          ExerciseMode.soundToLetter,
        ])
          ProgressEvent(
            atomId: 'ba.isolated',
            sessionId: 1,
            at: DateTime(2026),
            mode: mode,
            correct: true,
            attempt: 1,
            fastEnough: true,
          ),
      ]),
    );
    final controller = Get.put(
      LessonController(
        database: db,
        curriculum: curriculum,
        shapeLoader: shapeFromDisk,
        audio: LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    expect(controller.loadError.value, isNull);
    expect(controller.introAtoms, isEmpty);
    expect(controller.card.value, isNull);
    expect(controller.stage.value, LessonStage.exercise);
    expect(controller.current!.atom.id, 'ba.isolated');
    expect(controller.current!.mode, ExerciseMode.sayName);
    expect(find.text('№ 1 из 1'), findsOneWidget);
    await tester.runAsync(() => controller.submit(directOutcome: true));
    await settle(tester);
    await tester.tap(find.text('Продолжить'));
    await settle(tester);
    expect(controller.stage.value, LessonStage.finished);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });

  // У повторения соединённой формы не должны вновь открываться карточки
  // ни самой формы, ни уже знакомых вариантов ответа.
  testWidgets('закрепление формы не повторяет её объяснение', (tester) async {
    await tester.runAsync(
      () => db.appendAll([
        for (final topic in curriculum.topics.take(2))
          for (final id in topic.counterOf)
            if (id.startsWith('concept.'))
              AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026))
            else
              KnowledgeConfirmed(atomId: id, sessionId: 1, at: DateTime(2026)),
        ProgressEvent(
          atomId: 'ba.finalForm',
          sessionId: 2,
          at: DateTime(2026),
          mode: ExerciseMode.soundToLetter,
          correct: false,
          attempt: 1,
          fastEnough: true,
        ),
      ]),
    );
    final controller = Get.put(
      LessonController(
        database: db,
        curriculum: curriculum,
        shapeLoader: shapeFromDisk,
        audio: LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    expect(controller.loadError.value, isNull);
    expect(controller.stage.value, LessonStage.exercise);
    expect(controller.introAtoms, isEmpty);
    expect(controller.card.value, isNull);
    expect(controller.current!.atom.id, 'ba.finalForm');
    expect(find.text('Понятно'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });
}
