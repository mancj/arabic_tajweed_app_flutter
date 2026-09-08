import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [SingleChildScrollView] на каждом своём layout загоняет позицию в границы,
/// поэтому пружина у края живёт, только пока во время жеста ничего не тянет
/// layout до вьюпорта. Карточка буквы с анимированным узором это делала
/// через [LayoutBuilder]: перестройки внутри него идут в его layout.
/// Тест держит карточку «тихой»: с ней страница пружинит так же, как без неё.
void main() {
  void mockSensors() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['gyroscope', 'accelerometer', 'user_accel', 'magnetometer']) {
      messenger.setMockStreamHandler(
        EventChannel('dev.fluttercommunity.plus/sensors/$name'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (_) async => null,
    );
  }

  /// Тянет страницу вниз от самого верха и возвращает позицию скролла:
  /// с пружиной она уходит в минус, без неё остаётся нулём.
  Future<double> overscrollWith(WidgetTester tester, Widget probe) async {
    mockSensors();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                probe,
                const SizedBox(width: double.infinity, height: 3000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final gesture = await tester.startGesture(const Offset(200, 550));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final pixels = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    debugDefaultTargetPlatformOverride = null;
    return pixels;
  }

  testWidgets('страница с карточкой буквы пружинит у края, как и без неё', (
    tester,
  ) async {
    final bare = await overscrollWith(tester, const SizedBox(height: 200));
    expect(bare, lessThan(0), reason: 'стенд должен давать пружину');

    final withCard = await overscrollWith(
      tester,
      LetterWidgetCard(letter: 'ب', isArabic: true, onPlay: () {}),
    );
    expect(withCard, lessThan(0));
  });
}
