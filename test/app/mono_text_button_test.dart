// Длинная подпись под звуковым заданием выходила за край телефона.
// Текст должен переноситься, сохранять полную подпись и нажатие, в том
// числе с иконкой и увеличенным системным размером текста.
import 'package:arabic_tajweed_app/app/widgets/ui_kit/mono_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('длинное действие на телефоне, размер текста $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var taps = 0;
      const title = 'Не слышно? Показать название';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonoTextButton(
                  title: title,
                  icon: Icons.volume_up_rounded,
                  onPressed: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.text(title));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(304));
      expect(
        tester.getSize(find.byType(MonoTextButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
