// Постоянно парящие частицы не должны рисовать скрытый экран или обходить
// системное отключение анимаций. Кадры полёта не перестраивают родителя,
// а после смены источника и закрытия экрана не остаётся старых подписок.
// После заполнения искры появляются по всей окружности и летят наружу:
// общий подъём вверх увёл бы нижние частицы внутрь кольца.
// Нулевые частоты и предел количества останавливают ненужные кадры,
// в том числе при обновлении.
import 'dart:ui' as ui;

import 'package:arabic_tajweed_app/app/widgets/ui_kit/ring_sparks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSparks(
    WidgetTester tester,
    ValueNotifier<double> progress, {
    bool visible = true,
    bool reducedMotion = false,
    double activeEmissionRate = 18,
    double floatingEmissionRate = 3,
    int maxParticles = 48,
    double minRadius = .5,
    double maxRadius = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: TickerMode(
          enabled: visible,
          child: Center(
            child: SizedBox.square(
              dimension: 264,
              child: RingSparks(
                progress: progress,
                color: Colors.orange,
                activeEmissionRate: activeEmissionRate,
                floatingEmissionRate: floatingEmissionRate,
                maxParticles: maxParticles,
                minRadius: minRadius,
                maxRadius: maxRadius,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('парящие искры расходятся наружу со всех сторон кольца', (
    tester,
  ) async {
    final progress = ValueNotifier(1.0);
    addTearDown(progress.dispose);
    await pumpSparks(
      tester,
      progress,
      floatingEmissionRate: 24,
      maxParticles: 96,
      minRadius: 2,
      maxRadius: 2,
    );
    for (var frame = 0; frame < 190; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Замораживаем готовый рисунок, чтобы чтение пикселей не двигало полёт.
    await pumpSparks(
      tester,
      progress,
      visible: false,
      floatingEmissionRate: 24,
      maxParticles: 96,
      minRadius: 2,
      maxRadius: 2,
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(
        of: find.byType(RingSparks),
        matching: find.byType(RepaintBoundary),
      ),
    );
    var width = 0;
    var height = 0;
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        width = image.width;
        height = image.height;
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });
    expect(pixels, isNotNull);
    var left = false;
    var right = false;
    var top = false;
    var bottom = false;
    var inside = 0;
    // Оставляем запас на радиус точки 2 px и сглаживание её края.
    final innerRadius =
        const SegmentedRingGeometry().radiusFor(const Size.square(264)) - 4;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (pixels![(y * width + x) * 4 + 3] < 10) continue;
        final point = Offset(x + .5 - width / 2, y + .5 - height / 2);
        if (point.distanceSquared < innerRadius * innerRadius) inside++;
        left = left || x < width / 2 - 64;
        right = right || x > width / 2 + 64;
        top = top || y < height / 2 - 64;
        bottom = bottom || y > height / 2 + 64;
      }
    }
    expect([left, right, top, bottom], everyElement(isTrue));
    expect(inside, 0, reason: 'Парящие частицы уходят от кольца, а не внутрь');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('частоты и предел количества работают при смене параметров', (
    tester,
  ) async {
    final progress = ValueNotifier(.5);
    addTearDown(progress.dispose);
    await pumpSparks(
      tester,
      progress,
      activeEmissionRate: 0,
      floatingEmissionRate: 0,
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await pumpSparks(
      tester,
      progress,
      activeEmissionRate: 24,
      floatingEmissionRate: 0,
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isTrue);
    await pumpSparks(
      tester,
      progress,
      activeEmissionRate: 0,
      floatingEmissionRate: 0,
    );
    for (var frame = 0; frame < 100; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isFalse);

    await pumpSparks(
      tester,
      progress,
      activeEmissionRate: 0,
      floatingEmissionRate: 8,
      maxParticles: 8,
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    progress.value = 1;
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isTrue);

    await pumpSparks(
      tester,
      progress,
      floatingEmissionRate: 8,
      maxParticles: 0,
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('пустое кольцо и уменьшенное движение не запрашивают кадры', (
    tester,
  ) async {
    final progress = ValueNotifier(0.0);
    addTearDown(progress.dispose);
    await pumpSparks(tester, progress);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    progress.value = .5;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await pumpSparks(tester, progress, reducedMotion: true);
    progress.value = 1;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('парение прекращается вне видимого и активного экрана', (
    tester,
  ) async {
    final progress = ValueNotifier(1.0);
    addTearDown(progress.dispose);
    await pumpSparks(tester, progress);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await pumpSparks(tester, progress, visible: false);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(minutes: 1));

    await pumpSparks(tester, progress);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('новый источник заменяет старый, закрытие удаляет подписку', (
    tester,
  ) async {
    final oldProgress = _Progress(0);
    final newProgress = _Progress(0);
    addTearDown(oldProgress.dispose);
    addTearDown(newProgress.dispose);
    await pumpSparks(tester, oldProgress);
    await pumpSparks(tester, newProgress);
    await tester.pumpAndSettle();

    oldProgress.value = .5;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(oldProgress.isObserved, isFalse);

    newProgress.value = .5;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(newProgress.isObserved, isFalse);
    newProgress.value = 1;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('следующий экран приостанавливает парение предыдущего', (
    tester,
  ) async {
    final progress = ValueNotifier(1.0);
    addTearDown(progress.dispose);
    await pumpSparks(tester, progress);
    await tester.pump(const Duration(milliseconds: 100));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const SizedBox.shrink(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    navigator.pop();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('кадры частиц не перестраивают содержимое экрана', (
    tester,
  ) async {
    final progress = ValueNotifier(0.0);
    addTearDown(progress.dispose);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            builds++;
            return Center(
              child: SizedBox.square(
                dimension: 200,
                child: RingSparks(progress: progress, color: Colors.orange),
              ),
            );
          },
        ),
      ),
    );
    final initialBuilds = builds;
    for (var i = 1; i <= 20; i++) {
      progress.value = (i / 10).clamp(0.0, 1.0);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(builds, initialBuilds);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Progress extends ValueNotifier<double> {
  _Progress(super.value);

  bool get isObserved => hasListeners;
}
