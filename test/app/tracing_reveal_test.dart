import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';

/// Промахи считает сам холст и после серии показывает, как пишется. Для
/// урока это подсказка, а не ошибка: человек обводит по контуру, и собранная
/// буква сразу засчитывается верным ответом с окном успеха. См. SPEC.md §5.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProgressDatabase db;
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  setUp(() {
    db = ProgressDatabase(NativeDatabase.memory());
    mockPlatformPlugins();
  });
  tearDown(() async {
    // Контроллер закрывается, пока подмены каналов ещё живы: они снимаются
    // до tearDown, и плеер при закрытии иначе стучится в пустоту.
    await db.close();
  });

  Future<void> closeLesson() async {
    await Get.delete<LessonController>();
    Get.reset();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Доходит до первого задания на письмо.
  Future<LessonController> openAtTracing(
    WidgetTester tester, {
    ExerciseMode mode = ExerciseMode.trace,
  }) async {
    Get.put(
      LessonController(
        shapeLoader: (asset) async => TracingShapeSvg.parse(
          File('assets/svg/alphabet/$asset.svg').readAsStringSync(),
          id: asset,
        ),
        database: db,
        curriculum: curriculum,
        topicId: 'm.first',
        audio: LetterAudio(player: AudioPlayer(playerId: 'test')),
      ),
    );
    addTearDown(closeLesson);
    await tester.pumpWidget(const GetMaterialApp(home: LessonPage()));
    await settle(tester);
    final c = Get.find<LessonController>();
    while (c.stage.value != LessonStage.finished) {
      if (c.stage.value == LessonStage.intro) {
        await tester.runAsync(c.nextIntro);
      } else if (c.card.value != null) {
        await tester.runAsync(c.dismissCard);
      } else {
        if (c.isTracingTask && c.current!.mode == mode) break;
        await tester.runAsync(c.answerCorrectly);
        await settle(tester);
        await tester.tap(find.text('Продолжить'));
      }
      await settle(tester);
    }
    expect(c.current?.mode, mode, reason: 'в уроке нет нужного письма');
    return c;
  }

  testWidgets('подсказка холста — не ошибка, обведённая буква засчитывается', (
    tester,
  ) async {
    final c = await openAtTracing(tester);
    final before = c.current;
    expect(find.text('Готово'), findsNothing);
    c.onTracingRevealed();
    await settle(tester);
    expect(c.wasWrong.value, isFalse, reason: 'разбора с кнопкой «Ясно» нет');
    expect(c.tracingHint.value, 'Обведите по подсказке');

    // Человек обвёл по контуру: холст собрал букву — ответ верный.
    await c.onTracingMerged();
    await settle(tester);
    expect(c.wasWrong.value, isFalse);
    expect(c.wasCorrect.value, isTrue);
    expect(
      tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).enabled,
      isFalse,
      reason: 'после правильной обводки добавлять штрихи уже нельзя',
    );
    expect(find.text('Верно!'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(
      c.current,
      same(before),
      reason: 'результат показывается до перехода',
    );
    await tester.tap(find.text('Продолжить'));
    await settle(tester);
    expect(c.current, isNot(same(before)), reason: 'урок пошёл дальше');
  });

  testWidgets('письмо по памяти открывает результат без кнопки «Готово»', (
    tester,
  ) async {
    final c = await openAtTracing(tester, mode: ExerciseMode.traceFromMemory);

    expect(find.text('Готово'), findsNothing);
    await c.onTracingMerged();
    await settle(tester);

    expect(c.wasCorrect.value, isTrue);
    expect(find.text('Верно!'), findsOneWidget);
  });
}
