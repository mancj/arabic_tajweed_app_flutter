import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/pages/home/home_page.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';

void main() {
  testWidgets('проверка на реальной странице', (tester) async {
    // Окно как у телефона: холст квадратный, и в широком тестовом окне
    // 800x600 он не помещается по высоте.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Набор букв и первая фигура читаются из ассетов в две очереди.
    // Настоящий ввод-вывод живёт вне поддельных часов теста, поэтому и
    // контроллер заводится, и загрузка ждётся внутри runAsync: снаружи
    // future просто не дошагает до конца, и тест повиснет.
    late HomeController controller;
    await tester.runAsync(() async {
      controller = Get.put(HomeController());
      await controller.ready;
      // Ба: тест ведёт линию и ставит точку, значит нужна буква с точкой.
      // Первой в наборе идёт алиф, у которого её нет.
      controller.setLetter(
        controller.letters.indexWhere((item) => item.letterId == 'ba'),
      );
      await controller.ready;
    });

    await tester.pumpWidget(const GetMaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    final box = tester.getRect(find.byType(DrawingCanvas));
    final shape = canvas.placeholder!.resolve(
      box.size,
      padding: canvas.placeholderPadding,
    );

    final metric = shape.paths.first.computeMetrics().first;
    final points = [
      // Шаг как у настоящего пальца: событий много и они частые.
      for (var d = 0.0; d < metric.length; d += 1.5)
        metric.getTangentForOffset(d)!.position + box.topLeft,
    ];

    final gesture = await tester.startGesture(points.first);
    for (final point in points.skip(1)) {
      await gesture.moveTo(point);
    }
    await gesture.up();
    await tester.pump();

    await tester.tapAt(shape.dots.first + box.topLeft);
    await tester.pump();

    expect(controller.drawing.strokes.length, 2);
    expect(controller.drawing.check().isMatch, isTrue);
  });
}
