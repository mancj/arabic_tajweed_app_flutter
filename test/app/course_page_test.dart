import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/course/course_dashboard.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_path_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_binding.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/plugin_mocks.dart';

/// Главная кнопка и витрина запускают показанный план, а галочка старого
/// занятия не подменяет знания. Оглавление доступно отдельно, включая
/// закрытые темы.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
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
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<CourseController> open(WidgetTester tester, {AppClock? clock}) async {
    final c = Get.put(
      CourseController(database: db, curriculum: curriculum, clock: clock),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: const CoursePage(),
        getPages: [
          GetPage(
            name: DebugPage.routeName,
            page: () => const DebugPage(),
            binding: DebugPageBinding(),
          ),
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

  // Выбранный день переживает перезапуск, а сброс из меню возвращает
  // календарь к времени устройства навсегда, сохраняя историю занятий.
  // Проверка защищает от сброса только в памяти или фиксации реального дня.
  testWidgets('выбранная дата сохраняется и сбрасывается из меню отладки', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Get.put(SharedPreferenceManager(preferences), permanent: true);
    var actualNow = DateTime(2026, 9, 14, 10, 30);
    DateTime systemNow() => actualNow;
    final clock = Get.put(
      AppClock(systemNow: systemNow, preferences: preferences),
      permanent: true,
    );
    final c = await open(tester, clock: clock);
    final selectedDay = find.descendant(
      of: find.byType(CourseActivityWeek),
      matching: find.text('12'),
    );

    await tester.tap(selectedDay);
    await settle(tester);

    expect(DateUtils.isSameDay(c.today, DateTime(2026, 9, 12)), isTrue);
    await tester.runAsync(
      () => c.repository.finishSession(
        sessionId: 1,
        purpose: LessonPurpose.standard,
        exerciseCount: 0,
        firstTryCorrect: 0,
      ),
    );
    final summaries = await db.readSessionSummaries();
    expect(DateUtils.isSameDay(summaries.single.at, c.today), isTrue);
    final restarted = AppClock(systemNow: systemNow, preferences: preferences);
    expect(DateUtils.isSameDay(restarted.now, c.today), isTrue);

    await tester.ensureVisible(find.text('Меню отладки'));
    await tester.tap(find.text('Меню отладки'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Сброс'),
      500,
      scrollable: find.descendant(
        of: find.byType(DebugPage),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Сброс'));
    await settle(tester);
    await tester.tap(find.text('Сбросить дату'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(clock.now, actualNow);
    expect(preferences.containsKey('debugToday'), isFalse);
    final afterReset = AppClock(systemNow: systemNow, preferences: preferences);
    expect(afterReset.now, actualNow);
    actualNow = DateTime(2026, 9, 15, 8, 45);
    expect(clock.now, actualNow);
    expect(afterReset.now, actualNow);

    Get.back();
    await settle(tester);
    Get.back();
    await settle(tester);
    expect(
      tester.widget<CourseActivityWeek>(find.byType(CourseActivityWeek)).today,
      actualNow,
    );
    expect((await db.readSessionSummaries()).single.at, summaries.single.at);
  });

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
      expect((Get.arguments as Map)[LessonBinding.continuePlanningArg], isTrue);
      expect(c.opening.value, isTrue);
      Get.back();
      await settle(tester);
      expect(c.opening.value, isFalse);
    },
  );

  testWidgets('нажатие на витрину запускает показанное занятие', (
    tester,
  ) async {
    final c = await open(tester);
    final plan = c.nextPlan.value;

    await tester.tap(find.byType(CourseLessonPreview));
    await settle(tester);

    expect((Get.arguments as Map)['plan'], same(plan));
    expect((Get.arguments as Map)[LessonBinding.continuePlanningArg], isTrue);
  });

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
    expect(find.text('Перейти к этой теме'), findsOneWidget);
  });

  // Во время общего повторения у плана нет topicId. «Мой путь» всё равно
  // должен считать блок впереди текущей границы будущим и вести в проверку,
  // а не предлагать начать его напрямую.
  testWidgets('Мой путь позволяет перейти к теме во время общего повтора', (
    tester,
  ) async {
    final c = await open(tester);
    c.nextPlan.value = const LessonPlan(
      template: LessonTemplate.review,
      newAtoms: [],
      reviewAtoms: [],
      reason: 'общий повтор',
    );
    await tester.ensureVisible(find.text('Мой путь'));
    await tester.tap(find.text('Мой путь'));
    await settle(tester);
    await tester.tap(find.text('Буквы и их формы'));
    await settle(tester);
    final topic = c.curriculum.topics.firstWhere((t) => t.id == 'm.forms');
    await tester.ensureVisible(find.text(topic.title));
    await settle(tester);
    await tester.tap(find.text(topic.title));
    await settle(tester);

    expect(c.nextPlan.value?.topicId, isNull);
    expect(
      tester.widget<CourseTopicPage>(find.byType(CourseTopicPage)).topicId,
      topic.id,
    );
    expect(find.text('Перейти к этой теме'), findsOneWidget);
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
    expect(c.lessonFocus, 'Закрепление и новое');
    expect(c.lessonDetail, contains('по пробелам'));
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
    // Даже уже доступный модуль соединений не обгоняет следующую группу
    // букв в программе. Сам прогноз не записывает знания.
    expect(c.upcomingTopic.value!.topic.id, 'm.jim');
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
    expect(find.text('Перейти к этой теме'), findsOneWidget);
  });
}
