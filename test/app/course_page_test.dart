import 'dart:io';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_path_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Главная кнопка запускает показанный план, а галочка старого занятия
/// не подменяет знания. Оглавление доступно отдельно, включая закрытые темы.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final file in ['stage1', 'stage2'])
      CurriculumLoader.parse(
        File('assets/curriculum/$file.json').readAsStringSync(),
      ),
  ]);
  late ProgressDatabase db;
  setUp(() {
    db = ProgressDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    Get.reset();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<CourseController> open(WidgetTester tester) async {
    final c = Get.put(CourseController(database: db, curriculum: curriculum));
    await tester.pumpWidget(
      GetMaterialApp(
        home: const CoursePage(),
        getPages: [
          GetPage(
            name: '/lesson',
            page: () => const Scaffold(body: Text('Занятие')),
          ),
        ],
      ),
    );
    await settle(tester);
    return c;
  }

  testWidgets('главная показывает одно занятие и отдельный путь', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Начать занятие'), findsOneWidget);
    expect(find.text('Мой путь'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
    await tester.ensureVisible(find.text('Мой путь'));
    await tester.tap(find.text('Мой путь'));
    await settle(tester);
    expect(find.byType(CoursePathPage), findsOneWidget);
    expect(find.text('Буквы и их формы'), findsOneWidget);
    expect(find.text('Освоено букв: 0 из 28'), findsOneWidget);
  });

  testWidgets(
    'запуск передаёт именно показанный план и защищён от двойного нажатия',
    (tester) async {
      final c = await open(tester);
      final plan = c.nextPlan.value;
      await tester.tap(find.text('Начать занятие'));
      await settle(tester);
      expect((Get.arguments as Map)['plan'], same(plan));
      expect(c.opening.value, isTrue);
      Get.back();
      await settle(tester);
      expect(c.opening.value, isFalse);
    },
  );

  testWidgets('закрытая тема открывает описание и вход в проверку', (
    tester,
  ) async {
    final c = await open(tester);
    await tester.pumpWidget(
      GetMaterialApp(
        home: CourseTopicPage(controller: c, topicId: 'm.forms'),
      ),
    );
    await settle(tester);
    expect(find.text('Пока закрыто'), findsOneWidget);
    expect(find.text('Проверить знания и открыть'), findsOneWidget);
  });

  testWidgets('одна отметка о завершении не делает материал освоенным', (
    tester,
  ) async {
    await db.completeTopic('m.first', sessionId: 1);
    final c = await open(tester);
    expect(c.statuses.first.isDone, isFalse);
    expect(c.nextPlan.value!.topicId, 'm.first');
  });

  // Возврат с экрана упражнения и новый контроллер после перезапуска
  // должны выбрать недоученные буквы, а не следующую тему или общий повтор.
  testWidgets('досрочный выход и перезапуск сохраняют текущий материал', (
    tester,
  ) async {
    final c = await open(tester);
    await tester.tap(find.text('Начать занятие'));
    await settle(tester);
    await tester.runAsync(
      () => c.repository.recordAll([
        for (final id in curriculum.topics.first.counterOf)
          AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026)),
        ProgressEvent(
          atomId: 'alif.isolated',
          sessionId: 1,
          at: DateTime(2026),
          mode: ExerciseMode.sayName,
          correct: true,
          attempt: 1,
          fastEnough: true,
        ),
      ]),
    );
    Get.back();
    await settle(tester);
    expect(c.nextPlan.value!.topicId, 'm.first');
    expect(c.nextPlan.value!.newAtoms, isEmpty);
    expect(c.nextPlan.value!.isFocusedReview, isTrue);
    expect(c.nextPlan.value!.reviewAtoms, isNotEmpty);
    expect(c.lessonFocus, 'Короткое закрепление');
    expect(c.lessonDetail, contains('по оставшимся пробелам'));
    expect(c.currentTopic!.isDone, isFalse);
    final restarted = CourseController(database: db, curriculum: curriculum);
    await tester.runAsync(restarted.refreshBoard);
    expect(restarted.nextPlan.value!.topicId, 'm.first');
    expect(
      restarted.nextPlan.value!.reviewAtoms,
      c.nextPlan.value!.reviewAtoms,
    );
    await tester.tap(find.text('Начать занятие'));
    await settle(tester);
    expect((Get.arguments as Map)['plan'], same(c.nextPlan.value));
    Get.back();
    await settle(tester);
  });

  testWidgets('после освоения букв следующий план содержит все их формы', (
    tester,
  ) async {
    for (final id in curriculum.topics.first.counterOf) {
      await db.append(
        id.startsWith('concept.')
            ? AtomIntroduced(atomId: id, sessionId: 1, at: DateTime(2026))
            : KnowledgeConfirmed(atomId: id, sessionId: 1, at: DateTime(2026)),
      );
    }
    final c = await open(tester);
    expect(c.statuses.first.isDone, isTrue);
    expect(c.nextPlan.value!.topicId, 'm.forms');
    expect(c.nextPlan.value!.newAtoms.where((a) => a.form != null).length, 10);
    // Прогноз должен учитывать раннее соединение букв, а не просто брать
    // следующую строку программы. Сам прогноз не записывает знания.
    expect(c.upcomingTopic.value!.topic.id, 'm.join');
    expect(
      (await db.readAll()).length,
      curriculum.topics.first.counterOf.length,
    );
  });

  testWidgets('после всего курса остаётся непустое повторение', (tester) async {
    for (final node in curriculum.nodes) {
      await db.append(
        node.atom.kind == AtomKind.concept
            ? AtomIntroduced(
                atomId: node.atom.id,
                sessionId: 1,
                at: DateTime(2026),
              )
            : KnowledgeConfirmed(
                atomId: node.atom.id,
                sessionId: 1,
                at: DateTime(2026),
              ),
      );
    }
    final c = await open(tester);
    expect(c.allDone, isTrue);
    expect(c.nextPlan.value!.template, LessonTemplate.review);
    expect(c.nextPlan.value!.reviewAtoms, isNotEmpty);
    expect(c.canStart, isTrue);
    expect(c.upcomingTopic.value, isNull);
  });

  testWidgets('следующий шаг открывает реальные условия закрытой темы', (
    tester,
  ) async {
    final c = await open(tester);
    final id = c.upcomingTopic.value!.topic.id;
    await tester.ensureVisible(find.text('Далее'));
    await tester.tap(find.text('Далее'));
    await settle(tester);
    expect(
      tester.widget<CourseTopicPage>(find.byType(CourseTopicPage)).topicId,
      id,
    );
    expect(find.text('Проверить знания и открыть'), findsOneWidget);
  });
}
