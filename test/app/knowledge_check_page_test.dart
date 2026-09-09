import 'package:flutter/widgets.dart';
import 'dart:io';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/knowledge_check_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/question_card.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../helpers/plugin_mocks.dart';

/// Ошибка в проверке не даёт зачёт, а подтверждённые элементы сохраняются
/// даже при неполном успехе. UI не должен объявлять тему открытой раньше.
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
      await tester.tap(find.text('Понятно'));
      await settle(tester);
      for (var i = 0; i < 8; i++) {
        final q = tester.widget<QuestionCard>(find.byType(QuestionCard));
        final reverse = i >= 4;
        final atom = curriculum.nodes
            .map((n) => n.atom)
            .firstWhere(
              (a) => reverse ? a.label == q.subject : a.display == q.subject,
            );
        var answer = reverse ? atom.display : atom.label;
        if (missOne && i == 0) {
          answer = curriculum.nodes
              .map((n) => n.atom)
              .firstWhere(
                (a) =>
                    a.form == atom.form &&
                    a.id != atom.id &&
                    find.text(a.label).evaluate().isNotEmpty,
              )
              .label;
        }
        final choice = find.text(answer).last;
        await Scrollable.ensureVisible(tester.element(choice), alignment: .5);
        await tester.pump();
        await tester.tap(choice);
        await tester.pump();
        await tester.tap(find.text('Ответить'));
        await settle(tester);
        if (i == 3) {
          expect((await db.readAll()).whereType<KnowledgeConfirmed>(), isEmpty);
        }
      }
      final log = await db.readAll();
      expect(log.whereType<KnowledgeConfirmed>().length, missOne ? 3 : 4);
      expect(
        find.text(missOne ? 'Часть знаний подтверждена' : 'Тема доступна'),
        findsOneWidget,
      );
      expect(c.statuses[1].canPractice, !missOne);
      expect(tester.takeException(), isNull);
    });
  }
}
