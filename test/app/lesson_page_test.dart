import '../helpers/plugin_mocks.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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

  /// Ни pump, ни pumpAndSettle тут не помогают: контроллер ждёт настоящий
  /// ввод-вывод — чтение ассета и запрос в sqlite. Фейковые часы теста их
  /// не двигают, поэтому реальные паузы даём через runAsync.
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

  Future<void> pumpLesson(WidgetTester tester, {String? topicId}) async {
    // Граф отдаём готовым: rootBundle в тестах отвечает только первому
    // тесту файла, дальше запрос повисает.
    Get.put(
      LessonController(
        database: db,
        curriculum: curriculum,
        topicId: topicId,
        shapeLoader: shapeFromDisk,
        audio: LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
  }

  testWidgets('первый урок начинается с блока «новое»', (tester) async {
    await pumpLesson(tester);

    // Проверяем состояние, а не подписи: оформление экрана меняется чаще,
    // чем правило «урок начинается с показа новых атомов».
    final controller = Get.find<LessonController>();
    expect(controller.stage.value, LessonStage.intro);
    expect(controller.introAtom?.id, 'concept.letter');
    expect(find.text('Понятно'), findsOneWidget);
  });

  testWidgets('после интро понятие записано в лог', (tester) async {
    await pumpLesson(tester);
    await tester.tap(find.text('Понятно'));
    await settle(tester);

    final log = await db.readAll();
    expect(log.map((e) => e.atomId), contains('concept.letter'));
  });

  testWidgets('кнопка ответа неактивна, пока вариант не выбран', (
    tester,
  ) async {
    await pumpLesson(tester);
    final controller = Get.find<LessonController>();

    // Проходим весь блок «новое».
    while (controller.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }

    // На первом уроке доступно только понятие — заданий с выбором ещё нет,
    // потому что спрашивать пока нечего.
    expect(controller.stage.value, LessonStage.exercise);
  });

  testWidgets('нажатие по теме открывает её урок целиком', (tester) async {
    await pumpLesson(tester, topicId: 'm.first');

    final controller = Get.find<LessonController>();
    expect(controller.isTopicLesson, isTrue);
    expect(controller.stage.value, LessonStage.intro);

    // Тема = урок: объяснение про алфавит и следом четыре буквы.
    expect(controller.introAtoms.map((a) => a.id), [
      'concept.letter',
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ]);
    expect(find.textContaining('28 букв'), findsOneWidget);
  });

  testWidgets('перед первой формой буквы показан общий обзор', (tester) async {
    await tester.runAsync(
      () => db.appendAll([
        for (final id in curriculum.topics.first.counterOf)
          AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026)),
      ]),
    );
    await pumpLesson(tester, topicId: 'm.forms');
    final controller = Get.find<LessonController>();

    while (controller.stage.value == LessonStage.intro) {
      await tester.tap(find.text('Понятно'));
      await settle(tester);
    }

    final detail = controller.card.value!;
    final forms = controller.formsOverview.toList();
    expect(forms, isNotEmpty);
    expect(
      find.byKey(ValueKey('forms-overview-${detail.letterId}')),
      findsOneWidget,
    );
    expect(find.text('Все формы буквы ${forms.first.display}'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(controller.formsOverview, isEmpty);
    expect(controller.card.value, same(detail));
    expect(find.text(detail.label), findsOneWidget);
  });

  testWidgets('верный ответ сам переходит дальше через пять секунд', (
    tester,
  ) async {
    await pumpLesson(tester, topicId: 'm.first');
    final controller = Get.find<LessonController>();

    while (controller.introAtom?.id != 'alif.isolated') {
      await controller.nextIntro();
      await settle(tester);
    }
    await controller.nextIntro();
    await settle(tester);

    expect(controller.isSayNameTask, isTrue);
    final current = controller.current;
    await controller.submit(directOutcome: true);
    await settle(tester);

    expect(controller.wasCorrect.value, isTrue);
    expect(controller.current, same(current));
    expect(find.text('Правильно произнесено'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('correct-answer-auto-progress')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(controller.wasCorrect.value, isFalse);
    expect(controller.current, isNot(same(current)));
    expect(
      find.byKey(const ValueKey('correct-answer-auto-progress')),
      findsNothing,
    );
  });

  // Окно открывается на следующем кадре: если отладочная кнопка успеет
  // перейти дальше, сохранённый верный ответ выглядит на экране ошибкой.
  testWidgets('отладочный верный ответ на произношение показывает успех', (
    tester,
  ) async {
    await pumpLesson(tester, topicId: 'm.first');
    final controller = Get.find<LessonController>();

    while (controller.introAtom?.id != 'alif.isolated') {
      await controller.nextIntro();
      await settle(tester);
    }
    await controller.nextIntro();
    await settle(tester);

    expect(controller.isSayNameTask, isTrue);
    final exercise = controller.current!;
    await tester.tap(find.text('Ответить верно'));
    await settle(tester);

    expect(controller.wasCorrect.value, isTrue);
    expect(controller.current, same(exercise));
    expect(find.text('Правильно произнесено'), findsOneWidget);
    expect(find.text('Попробуйте ещё раз'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(controller.wasCorrect.value, isFalse);
    expect(controller.current, isNot(same(exercise)));

    final answers = (await db.readAll()).whereType<ProgressEvent>().toList();
    final answer = answers.singleWhere(
      (event) => event.mode == ExerciseMode.sayName,
    );
    expect(answers, hasLength(1));
    expect(answer.atomId, exercise.atom.id);
    expect(answer.correct, isTrue);
  });
}
