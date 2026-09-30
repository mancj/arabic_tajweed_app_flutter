import 'package:flutter/widgets.dart';
import 'dart:io';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/knowledge_check_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/answer_option.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/knowledge_check.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../helpers/plugin_mocks.dart';

/// Ошибка в проверке не даёт зачёт, а подтверждённые элементы сохраняются
/// даже при неполном успехе. Далёкую тему можно открыть короткой проверкой:
/// старый вариант требовал до 186 ответов за один подход.
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

  for (final missOne in [false, true]) {
    testWidgets('проверка сохраняет результат: ошибка=$missOne', (
      tester,
    ) async {
      final c = Get.put(CourseController(database: db, curriculum: curriculum));
      await tester.pumpWidget(const GetMaterialApp(home: CoursePage()));
      await settle(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          home: KnowledgeCheckPage(controller: c, topic: curriculum.topics[1]),
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
        for (final stage in [1, 2, 3])
          CurriculumLoader.parse(
            File('assets/curriculum/stage$stage.json').readAsStringSync(),
          ),
      ]);
      final topic = fullCourse.topics.firstWhere(
        (t) => t.id == 'm.haraka.intro',
      );
      final c = Get.put(CourseController(database: db, curriculum: fullCourse));
      await tester.pumpWidget(const GetMaterialApp(home: CoursePage()));
      await settle(tester);
      await tester.pumpWidget(
        GetMaterialApp(
          home: KnowledgeCheckPage(controller: c, topic: topic),
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
