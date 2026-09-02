import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressDatabase db;
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  setUp(() {
    db = ProgressDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  /// Настоящий ввод-вывод — чтение ассета и sqlite — фейковые часы теста
  /// не двигают, поэтому паузы даём через runAsync.
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

  Future<void> pumpCourse(WidgetTester tester) async {
    Get.put(CourseController(database: db, curriculum: curriculum));
    await tester.pumpWidget(const GetMaterialApp(home: CoursePage()));
    await settle(tester);
  }

  testWidgets('на чистом старте показаны темы и кнопка «Начать»', (
    tester,
  ) async {
    await pumpCourse(tester);

    expect(find.text('Этап 1 · Буквы'), findsOneWidget);
    expect(find.text('Первые буквы: ا ب ت ث'), findsWidgets);
    expect(find.text('Начать'), findsOneWidget);
  });

  testWidgets('закрытая тема объясняет условие', (tester) async {
    await pumpCourse(tester);
    expect(find.textContaining('нужно освоить'), findsWidgets);
  });

  testWidgets('нажимаются только открытые темы', (tester) async {
    await db.append(
      AtomIntroduced(
        atomId: 'concept.letter',
        sessionId: 1,
        at: DateTime(2026, 1, 1),
      ),
    );
    await pumpCourse(tester);

    final controller = Get.find<CourseController>();
    final open = controller.statuses.where((s) => s.canPractice).toList();
    final locked = controller.statuses.where((s) => !s.canPractice).toList();

    expect(open, isNotEmpty);
    expect(locked, isNotEmpty, reason: 'закрытые темы должны остаться');
    expect(open.every((s) => s.state != TopicState.locked), isTrue);

    // Урок, которым занимались последним, помечен как текущий.
    expect(
      open.any((s) => s.state == TopicState.current),
      isTrue,
      reason: 'текущий урок должен быть нажимаемым',
    );
  });

  testWidgets('начатая тема переводит кнопку в «Продолжить»', (tester) async {
    await db.append(
      AtomIntroduced(
        atomId: 'concept.letter',
        sessionId: 1,
        at: DateTime(2026, 1, 1),
      ),
    );
    await pumpCourse(tester);

    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
  });

  testWidgets('пройденный урок отмечается закрытым', (tester) async {
    await pumpCourse(tester);
    final controller = Get.find<CourseController>();
    final topic = controller.currentTopic!;

    // Урок закрывается собственной отметкой, а не освоенностью букв:
    // раньше «Продолжить» открывал урок без привязки к теме, и закрывать
    // по окончании было нечего.
    await db.completeTopic(topic.topic.id, sessionId: 1);
    await controller.refreshBoard();
    await settle(tester);

    final after = controller.statuses.firstWhere(
      (s) => s.topic.id == topic.topic.id,
    );
    expect(after.state, TopicState.done);
    expect(after.showsMastery, isFalse);
    expect(find.text('пройден'), findsOneWidget);
  });

  testWidgets('открытый и брошенный урок не становится пройденным', (
    tester,
  ) async {
    await pumpCourse(tester);
    final controller = Get.find<CourseController>();
    final topic = controller.currentTopic!.topic.id;

    // Человек зашёл в урок, посмотрел объяснение и вышел: атомы показаны,
    // но сессия не пройдена. Отметки быть не должно.
    await db.append(
      AtomIntroduced(
        atomId: 'concept.letter',
        sessionId: 1,
        at: DateTime(2026, 1, 1),
      ),
    );
    await controller.refreshBoard();
    await settle(tester);

    final after = controller.statuses.firstWhere((s) => s.topic.id == topic);
    expect(after.state, isNot(TopicState.done));
    expect(await db.readCompletions(), isEmpty);
    expect(find.text('пройден'), findsNothing);
  });

  testWidgets('когда впереди замок, кнопка предлагает повторить', (
    tester,
  ) async {
    await pumpCourse(tester);
    final controller = Get.find<CourseController>();
    final first = controller.currentTopic!.topic.id;

    // Урок пройден, но следующий ждёт освоенности букв. Кнопка не должна
    // обещать «продолжить» и вести в урок с галочкой.
    await db.completeTopic(first, sessionId: 1);
    await controller.refreshBoard();
    await settle(tester);

    // Тема пройдена, следующая закрыта: повторять есть что, но темы
    // впереди нет — занятие соберёт планировщик.
    expect(controller.continueLabel, 'Повторить');
    expect(controller.continueTarget, isNull);
    expect(controller.nextLocked, isNotNull);
    expect(first, isNotEmpty);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.textContaining('нужно освоить'), findsWidgets);
  });

  testWidgets('когда всё пройдено, кнопка ведёт в повторение', (tester) async {
    await pumpCourse(tester);
    final controller = Get.find<CourseController>();

    for (final status in [...controller.statuses]) {
      await db.completeTopic(status.topic.id, sessionId: 1);
    }
    await controller.refreshBoard();
    await settle(tester);

    // Тем впереди нет: занятие собирает планировщик, а не первая тема
    // из списка — гонять по пройденному подряд бессмысленно.
    expect(controller.allDone, isTrue);
    expect(controller.continueTarget, isNull);
    expect(controller.continueLabel, 'Повторить');
    expect(find.text('Повторить'), findsOneWidget);
  });
}
