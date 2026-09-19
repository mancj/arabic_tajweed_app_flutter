import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

// Раньше при изменении прогресса волна меняла форму скачком. Её фаза должна
// оставаться неподвижной, пока заполнение плавно движется к новому значению.
void main() {
  testWidgets('волна сохраняет форму при изменении прогресса', (
    tester,
  ) async {
    Widget bar(double value) => MaterialApp(
      home: Scaffold(
        body: LessonProgressBar(value: value, wavy: true),
      ),
    );

    double progress() => tester
        .widget<ExpressiveLinearProgressIndicator>(
          find.byType(ExpressiveLinearProgressIndicator),
        )
        .value!;

    bool waveIsMoving() => tester
        .widget<TickerMode>(
          find.descendant(
            of: find.byType(LessonProgressBar),
            matching: find.byType(TickerMode),
          ),
        )
        .enabled;

    await tester.pumpWidget(bar(.25));
    await tester.pumpAndSettle();
    expect(progress(), .25);
    expect(waveIsMoving(), isFalse);

    await tester.pumpWidget(bar(.75));
    await tester.pump(const Duration(milliseconds: 200));
    expect(progress(), greaterThan(.25));
    expect(progress(), lessThan(.75));
    expect(waveIsMoving(), isFalse);

    await tester.pumpAndSettle();
    expect(progress(), .75);
    expect(waveIsMoving(), isFalse);
  });
}
