import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Касание карточки не должно забирать прокрутку у списка. При изменениях
/// общего обработчика также должны сохраняться тап, быстрый отклик и
/// завершение удержания ровно один раз, включая системную отмену касания.
void main() {
  const cardKey = ValueKey('card');

  Finder pressAnimation() => find.descendant(
    of: find.byKey(cardKey),
    matching: find.byType(AnimatedScale),
  );

  for (final axis in Axis.values) {
    for (final pause in [Duration.zero, const Duration(milliseconds: 150)]) {
      testWidgets('прокрутка $axis с карточки после паузы $pause', (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ListView(
              controller: controller,
              scrollDirection: axis,
              children: [
                AppGestureDetector(
                  key: cardKey,
                  onTap: () => taps++,
                  child: const SizedBox(width: 240, height: 240),
                ),
                const SizedBox(width: 2400, height: 2400),
              ],
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(cardKey)),
        );
        await tester.pump(pause);
        final delta = axis == Axis.vertical
            ? const Offset(0, -40)
            : const Offset(-40, 0);
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(delta);
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(controller.offset, greaterThan(0));
        expect(taps, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 0);
        expect(tester.widget<AnimatedScale>(pressAnimation()).scale, 1);
      });
    }
  }

  testWidgets('быстрый тап сохраняет отклик и вызывает действие один раз', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppGestureDetector(
            key: cardKey,
            onTap: () => taps++,
            child: const SizedBox(width: 240, height: 240),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(cardKey)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(pressAnimation()).scale, .98);
    expect(taps, 0);
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(pressAnimation()).scale, .98);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(pressAnimation()).scale, 1);
  });

  for (final cancel in [false, true]) {
    testWidgets('удержание заканчивается сразу: отмена=$cancel', (
      tester,
    ) async {
      var starts = 0;
      var ends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppGestureDetector(
              key: cardKey,
              onPressStart: () => starts++,
              onPressEnd: () => ends++,
              child: const SizedBox(width: 240, height: 240),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(cardKey)),
      );
      expect(starts, 1);
      expect(ends, 0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(starts, 1);
      expect(ends, 0);
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      expect(ends, 1);
      await tester.pumpAndSettle();
      expect(ends, 1);
      expect(tester.widget<AnimatedScale>(pressAnimation()).scale, 1);
    });
  }
}
