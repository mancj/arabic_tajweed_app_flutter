// Защищает главное отличие письма огласовок: буква остаётся видимой,
// а общий холст проверяет положение знака относительно неё.
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_drawing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('карточка оставляет букву под закреплённым холстом', (
    tester,
  ) async {
    final controller = DrawingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HarakaDrawingCard(
              letterId: 'ba',
              title: 'Нарисуйте огласовку',
              hint: 'По памяти',
              onClear: controller.clear,
              controller: controller,
              matcher: const TracingMatcher(),
              mode: TracingMode.freehand,
              shape: TracingShapes.arabicBa,
              enabled: true,
              missesBeforeReveal: 3,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
    final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.mode, TracingMode.freehand);
    expect(canvas.placement, TracingPlacement.anchored);
    expect(canvas.placeholderOffset.dy, lessThan(0));
    expect(canvas.strokeWidth, HarakaDrawingCard.strokeWidth);
    expect(canvas.bandScale, HarakaDrawingCard.bandScale);
    expect(canvas.bandScale, greaterThan(1.65));
  });
}
