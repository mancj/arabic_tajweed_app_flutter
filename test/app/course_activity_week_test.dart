// Календарь появляется один раз: обновления данных и темы не должны снова
// скрывать дни. Отключение движения сразу завершает появление, а даты доступны
// экранному диктору даже до первого видимого кадра.
// Семь дней заканчиваются сегодняшним: понедельник, смена месяца и года
// не обрезают серию и не подставляют будущие даты.

import 'package:arabic_tajweed_app/app/pages/course/course_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 11);

  Future<void> mount(
    WidgetTester tester, {
    bool disableAnimations = false,
    Set<DateTime> days = const {},
    Brightness brightness = Brightness.light,
    DateTime? endingOn,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(brightness: brightness),
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Center(
            child: SizedBox(
              width: 400,
              child: CourseActivityWeek(days: days, today: endingOn ?? today),
            ),
          ),
        ),
      ),
    ),
  );

  Finder getHistory() => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Последние 30 дней') ?? false),
  );

  List<double> historyOpacities(WidgetTester tester) => tester
      .widgetList<FadeTransition>(
        find.descendant(
          of: getHistory(),
          matching: find.byType(FadeTransition),
        ),
      )
      .map((fade) => fade.opacity.value)
      .toList();

  double weekOpacity(WidgetTester tester, String label) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  List<double> allOpacities(WidgetTester tester) => tester
      .widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(CourseActivityWeek),
          matching: find.byType(FadeTransition),
        ),
      )
      .map((fade) => fade.opacity.value)
      .toList();

  testWidgets('последние семь дней проходят через неделю, месяц и год', (
    tester,
  ) async {
    await mount(
      tester,
      endingOn: DateTime(2027, 1, 6),
      disableAnimations: true,
      days: {DateTime(2026, 12, 31), DateTime(2027, 1, 5)},
    );
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label)
        .whereType<String>()
        .where((label) => RegExp(r'^(Пн|Вт|Ср|Чт|Пт|Сб|Вс),').hasMatch(label));
    expect(find.text('Последние 7 дней'), findsOneWidget);
    expect(labels, [
      'Чт, 31.12, занимались',
      'Пт, 1.1, без отметки',
      'Сб, 2.1, без отметки',
      'Вс, 3.1, без отметки',
      'Пн, 4.1, без отметки',
      'Вт, 5.1, занимались',
      'Ср, 6.1, сегодня, без отметки',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('дни доступны диктору с начала появления', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);

      expect(weekOpacity(tester, 'Пн'), 0);
      expect(
        find.bySemanticsLabel(RegExp(r'Пн, 5\.10, без отметки')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('12.9, без отметки'), findsOneWidget);
      expect(
        find.bySemanticsLabel('11.10, сегодня, без отметки'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('неделя появляется слева направо, кружочки только проявляются', (
    tester,
  ) async {
    await mount(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    expect(weekOpacity(tester, 'Пн'), greaterThan(weekOpacity(tester, 'Вт')));
    expect(weekOpacity(tester, 'Вт'), greaterThan(weekOpacity(tester, 'Ср')));
    expect(weekOpacity(tester, 'Вс'), 0);
    var previous = historyOpacities(tester);
    expect(previous.any((opacity) => opacity > 0), isTrue);
    expect(previous.any((opacity) => opacity == 0), isTrue);
    // Проверяем плавность каждого кружочка независимо от случайного порядка.
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      final current = historyOpacities(tester);
      for (var index = 0; index < current.length; index++) {
        expect(current[index], greaterThanOrEqualTo(previous[index]));
      }
      previous = current;
    }
    expect(allOpacities(tester), everyElement(1.0));

    await mount(tester, days: {today}, brightness: Brightness.dark);
    expect(allOpacities(tester), everyElement(1.0));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'отключение движения завершает появление без повторного запуска',
    (tester) async {
      await mount(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(allOpacities(tester).any((opacity) => opacity < 1), isTrue);

      await mount(tester, disableAnimations: true);
      expect(allOpacities(tester), everyElement(1.0));
      await mount(tester);
      expect(allOpacities(tester), everyElement(1.0));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester, disableAnimations: true);
      expect(allOpacities(tester), everyElement(1.0));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
