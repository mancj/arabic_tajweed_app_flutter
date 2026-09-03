import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:drift/native.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Первый урок целиком: знакомство с ا ب ت ث и двенадцать заданий.
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

  setUp(() => db = ProgressDatabase(NativeDatabase.memory()));
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

  testWidgets('урок объясняет алфавит, потом четыре буквы, потом задания', (
    tester,
  ) async {
    Get.put(
      LessonController(
        database: db,
        curriculum: curriculum,
        shapeLoader: shapeFromDisk,
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
    expect(find.textContaining('Алиф'), findsWidgets);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(find.textContaining('одна точка снизу'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(find.textContaining('две, и стоят сверху'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(find.textContaining('на одну больше'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(controller.stage.value, LessonStage.exercise);
  });
}
