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
    expect(find.text('Разные формы одной буквы'), findsNothing);
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
  });
}
