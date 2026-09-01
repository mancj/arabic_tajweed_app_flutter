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

    Get.put(HomeController());
    await tester.pumpWidget(const GetMaterialApp(home: HomePage()));
    // Буква подгружается из ассета — ждём, пока она доедет до холста.
    await tester.pumpAndSettle();

    final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    final box = tester.getRect(find.byType(DrawingCanvas));
    final shape = canvas.placeholder!.resolve(box.size, padding: canvas.placeholderPadding);

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

    final controller = Get.find<HomeController>();
    expect(controller.drawing.strokes.length, 2);
    expect(controller.drawing.check().isMatch, isTrue);
  });
}
