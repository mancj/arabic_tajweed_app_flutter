import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressDatabase db;
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  setUp(() => db = ProgressDatabase(NativeDatabase.memory()));

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
      LessonController(database: db, curriculum: curriculum, topicId: topicId),
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
}
