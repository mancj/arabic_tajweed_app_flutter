import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

/// Показ: холст сам обводит букву поверх контура, чтобы человек увидел,
/// с чего начинать и куда вести. Про это контур не сообщает ничего.
///
/// Обводится буква целиком — основа и следом точки, одной анимацией.
/// Показывать точки только после того, как человек справится с основой,
/// поздно: он к тому моменту уже решил, что рисует.
void main() {
  TracingShape letter(String name) => TracingShapeSvg.parse(
    File('assets/svg/alphabet/$name.svg').readAsStringSync(),
    id: name,
  );

  Future<void> pumpCanvas(
    WidgetTester tester, {
    TracingMode mode = TracingMode.tracing,
    bool showDemo = true,
    String name = 'ta_base',
    Duration gap = const Duration(milliseconds: 10),
  }) async {
    final shape = letter(name);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 329,
            height: 329,
            child: DrawingCanvas(
              placeholder: shape,
              placeholderPadding: 0,
              mode: mode,
              showDemo: showDemo,
              demoPartGap: gap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Идёт ли на холсте анимация. Показ — единственная, пока никто не рисует.
  bool isAnimating(WidgetTester tester) => tester.binding.hasScheduledFrame;

  /// Сколько показ идёт на самом деле.
  Future<Duration> demoTime(
    WidgetTester tester,
    String name, {
    Duration gap = const Duration(milliseconds: 10),
  }) async {
    await pumpCanvas(tester, name: name, gap: gap);
    var elapsed = Duration.zero;
    while (tester.binding.hasScheduledFrame && elapsed.inSeconds < 10) {
      await tester.pump(const Duration(milliseconds: 16));
      elapsed += const Duration(milliseconds: 16);
    }
    return elapsed;
  }

  /// У ба и та одна и та же основа, но у та на точку больше. Если бы показ
  /// шёл только по основе, время у них совпало бы; раз у та он дольше —
  /// точки обводятся в той же анимации, а не после того, как человек
  /// справится с основой сам.
  testWidgets('точки обводятся вместе с основой', (tester) async {
    final base = letter('ba_base').resolve(const Size(329, 329)).parts.first;
    final ta = letter('ta_base').resolve(const Size(329, 329)).parts.first;
    expect(
      base.paths.first.getBounds(),
      ta.paths.first.getBounds(),
      reason: 'основа у ба и та должна быть одна и та же',
    );

    final withOneDot = await demoTime(tester, 'ba_base');
    final withTwoDots = await demoTime(tester, 'ta_base');

    expect(
      withTwoDots,
      greaterThan(withOneDot),
      reason: 'лишняя точка та не попала в показ',
    );
  });

  /// Разгон и торможение живут внутри доли письма. Приложить кривую ко
  /// всей анимации нельзя: перо разгонялось бы к концу буквы и обрывалось
  /// на полном ходу, а выдержку и растворение растягивало бы зря.
  group('разгон пера', () {
    test('к концу письма буква обведена целиком', () {
      expect(TracingDemo.traced(TracingDemo.drawing), closeTo(1, 1e-9));
      expect(TracingDemo.traced(1), closeTo(1, 1e-9));
      expect(TracingDemo.traced(0), closeTo(0, 1e-9));
    });

    test('ease in out тормозит на краях и разгоняется в середине', () {
      const half = TracingDemo.drawing / 2;
      const quarter = TracingDemo.drawing / 4;

      expect(TracingDemo.traced(half), closeTo(0.5, 1e-6));
      expect(
        TracingDemo.traced(quarter),
        lessThan(0.25),
        reason: 'в начале перо идёт медленнее равномерного',
      );
    });

    test('кривая задаётся снаружи', () {
      const half = TracingDemo.drawing / 2;

      expect(
        TracingDemo.traced(half, curve: Curves.linear),
        closeTo(0.5, 1e-6),
      );
      expect(
        TracingDemo.traced(half, curve: Curves.easeIn),
        lessThan(TracingDemo.traced(half, curve: Curves.easeOut)),
      );
    });

    test('растворение идёт ровно, кривой не подчиняется', () {
      expect(TracingDemo.opacity(TracingDemo.holding), 1);
      expect(TracingDemo.opacity(1), 0);
      expect(
        TracingDemo.opacity((TracingDemo.holding + 1) / 2),
        closeTo(0.5, 1e-6),
      );
    });
  });

  /// Пауза между частями считается в длине показа, а не в кадрах: только
  /// так она одинаково попадает и в отрисовку, и в длительность.
  group('пауза между частями', () {
    test('удлиняет показ ровно на пропуски между частями', () {
      final ta = letter('ta_base').resolve(const Size(329, 329));
      expect(ta.parts.length, 2, reason: 'у та основа и часть с точками');

      expect(ta.traceLength(gap: 0), closeTo(ta.traceLength(), 1e-9));
      expect(
        ta.traceLength(gap: 30),
        closeTo(ta.traceLength() + 30, 1e-6),
        reason: 'между двумя частями один пропуск, не два',
      );
    });

    test('после последней части пропуска нет', () {
      final alif = letter('alif_base').resolve(const Size(329, 329));
      expect(alif.parts.length, 1, reason: 'у алифа одна часть');

      expect(alif.traceLength(gap: 100), closeTo(alif.traceLength(), 1e-9));
    });

    test('пропуски считаются от начальной части', () {
      final ta = letter('ta_base').resolve(const Size(329, 329));

      expect(
        ta.traceLength(gap: 30, from: 1),
        closeTo(ta.parts.last.traceLength(), 1e-6),
        reason: 'осталась одна часть — пропускать не между чем',
      );
    });
  });

  testWidgets('длинная пауза удлиняет показ', (tester) async {
    final quick = await demoTime(tester, 'ta_base');
    final slow = await demoTime(
      tester,
      'ta_base',
      gap: const Duration(milliseconds: 600),
    );

    expect(slow, greaterThan(quick));
  });

  testWidgets('под контуром показ запускается сам', (tester) async {
    await pumpCanvas(tester);
    await tester.pump(const Duration(milliseconds: 16));

    expect(isAnimating(tester), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('по памяти показа нет', (tester) async {
    await pumpCanvas(tester, mode: TracingMode.freehand);
    await tester.pump(const Duration(milliseconds: 16));

    expect(isAnimating(tester), isFalse);
  });

  testWidgets('showDemo выключает показ', (tester) async {
    await pumpCanvas(tester, showDemo: false);
    await tester.pump(const Duration(milliseconds: 16));

    expect(isAnimating(tester), isFalse);
  });

  testWidgets('показ доигрывает и уходит с холста сам', (tester) async {
    await pumpCanvas(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(isAnimating(tester), isTrue);

    // Дорисованная часть не должна остаться лежать: иначе её не отличить
    // от того, что нарисовал человек.
    await tester.pumpAndSettle();
    expect(isAnimating(tester), isFalse);
  });

  testWidgets('касание обрывает показ', (tester) async {
    await pumpCanvas(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(isAnimating(tester), isTrue);

    final box = tester.getRect(find.byType(DrawingCanvas));
    final gesture = await tester.startGesture(box.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      isAnimating(tester),
      isFalse,
      reason: 'человек взялся сам — показ должен уйти',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
