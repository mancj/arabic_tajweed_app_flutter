import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/plugin_mocks.dart';

/// [SingleChildScrollView] на каждом своём layout загоняет позицию в границы,
/// поэтому пружина у края живёт, только пока во время жеста ничего не тянет
/// layout до вьюпорта. Карточка буквы с анимированным узором это делала
/// через [LayoutBuilder]: перестройки внутри него идут в его layout.
/// Тест держит карточку «тихой»: с ней страница пружинит так же, как без неё.
void main() {
  /// Тянет страницу вниз от самого верха и возвращает позицию скролла:
  /// с пружиной она уходит в минус, без неё остаётся нулём.
  Future<double> overscrollWith(WidgetTester tester, Widget probe) async {
    mockPlatformPlugins();
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

  /// Scheherazade даёт строке большой запас сверху и снизу. Без
  /// компактной высоты и центрирования буква с огласовкой уезжает вверх.
  testWidgets('арабский глиф использует компактную строку и центр', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LetterWidgetCard(
          letter: 'طَ',
          isArabic: true,
          autoPlay: false,
          showPlay: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final glyph = tester.widget<Text>(find.text('طَ'));
    expect(glyph.style?.height, 1);

    final glyphArea = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 80,
    );
    expect(
      tester.getCenter(find.text('طَ')).dy,
      closeTo(tester.getCenter(glyphArea).dy, 0.1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
