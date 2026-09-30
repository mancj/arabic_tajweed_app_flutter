import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/glow_wave_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/record_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Проверяет смену кнопки на волну только во время ожидания ответа сервера:
/// иначе человек может начать вторую запись или увидеть анимацию после ошибки.
void main() {
  testWidgets('волна играет только во время проверки произношения', (
    tester,
  ) async {
    var starts = 0;

    Future<void> showBar({required bool checking}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RecordBar(
                recording: false,
                checking: checking,
                idleHint: 'Удерживайте кнопку',
                onPressStart: () => starts++,
              ),
            ),
          ),
        ),
      ),
    );

    await showBar(checking: false);
    expect(find.byType(CircleButton), findsOneWidget);
    expect(find.byType(GlowWaveWidget), findsNothing);

    await showBar(checking: true);
    expect(find.byType(CircleButton), findsNothing);
    expect(find.byType(GlowWaveWidget), findsOneWidget);
    expect(find.text('Проверяю…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(GlowWaveWidget));
    expect(starts, 0);

    await showBar(checking: false);
    expect(find.byType(GlowWaveWidget), findsNothing);
    expect(find.byType(CircleButton), findsOneWidget);
  });
}
