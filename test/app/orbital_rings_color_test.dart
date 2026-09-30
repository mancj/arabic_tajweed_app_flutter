// Виджет должен загружать Rive без настройки, сохранять квадратный размер
// и пропускать фон родителя сквозь пустую середину колец.
// Смена цвета и толщины не должна сбрасывать движение через новый контроллер.
// Раздельные настройки не должны утолщать соседний тип фигур.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arabic_tajweed_app/app/pages/debug/orbital_rings_debug_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/orbital_rings_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('Виджет прозрачный и меняет толщину без перезапуска', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    Widget preview(double thickness) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 240,
              height: 240,
              child: ColoredBox(
                color: const Color(0xFF39A7C2),
                child: OrbitalRingsWidget(thickness: thickness, playing: false),
              ),
            ),
          ),
        ),
      ),
    );
    Future<int> visiblePixels() async => (await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey))
          .toImage();
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final center = (120 * image.width + 120) * 4;
      expect(rgba!.getUint32(center), 0x39A7C2FF);
      var count = 0;
      for (var x = 0; x < image.width; x++) {
        if (rgba.getUint32((120 * image.width + x) * 4) != 0x39A7C2FF) {
          count++;
        }
      }
      image.dispose();
      return count;
    }))!;

    await tester.pumpWidget(preview(1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byType(rive.RiveWidget), findsOneWidget);
    expect(
      tester.getSize(find.byType(OrbitalRingsWidget)),
      const Size(240, 240),
    );
    final controller = tester
        .widget<rive.RiveWidget>(find.byType(rive.RiveWidget))
        .controller;
    final originalPixels = await visiblePixels();
    expect(originalPixels, greaterThan(0));

    await tester.pumpWidget(preview(3));
    await tester.pump();
    expect(
      tester.widget<rive.RiveWidget>(find.byType(rive.RiveWidget)).controller,
      same(controller),
    );
    expect(await visiblePixels(), greaterThan(originalPixels));
  });

  testWidgets('HEX-код меняет цвет без перезапуска анимации', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OrbitalRingsDebugPage()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final riveWidget = find.byType(rive.RiveWidget);
    expect(riveWidget, findsOneWidget);
    final controller = tester.widget<rive.RiveWidget>(riveWidget).controller;

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '#0A84FF');
    await tester.tap(find.text('Применить'));
    await tester.pump();

    expect(
      tester
          .widget<ColorFiltered>(find.byType(ColorFiltered).first)
          .colorFilter,
      const ColorFilter.mode(Color(0xFF0A84FF), BlendMode.modulate),
    );
    expect(
      tester.widget<rive.RiveWidget>(riveWidget).controller,
      same(controller),
    );
    await tester.ensureVisible(find.byType(Slider).first);
    await tester.drag(find.byType(Slider).first, const Offset(100, 0));
    await tester.pump();
    expect(
      tester
          .widget<OrbitalRingsWidget>(find.byType(OrbitalRingsWidget))
          .ringThickness,
      greaterThan(1),
    );
    expect(
      tester
          .widget<OrbitalRingsWidget>(find.byType(OrbitalRingsWidget))
          .dashThickness,
      1,
    );
    await tester.ensureVisible(find.byType(Slider).last);
    await tester.drag(find.byType(Slider).last, const Offset(100, 0));
    await tester.pump();
    expect(
      tester
          .widget<OrbitalRingsWidget>(find.byType(OrbitalRingsWidget))
          .dashThickness,
      greaterThan(1),
    );
    expect(
      tester.widget<rive.RiveWidget>(riveWidget).controller,
      same(controller),
    );
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Кольца и штрихи утолщаются независимо', (tester) async {
    final boundaryKey = GlobalKey();
    Widget preview(double rings, double dashes) => MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox.square(
            dimension: 300,
            child: ColoredBox(
              color: const Color(0xFF39A7C2),
              child: OrbitalRingsWidget(
                ringThickness: rings,
                dashThickness: dashes,
                playing: false,
              ),
            ),
          ),
        ),
      ),
    );

    Future<(int, int)> countPixels() async => (await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey))
          .toImage();
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(rgba.getUint32((144 * image.width + 150) * 4), 0x39A7C2FF);
      var rings = 0;
      var dashes = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final radius = math.sqrt(math.pow(x - 150, 2) + math.pow(y - 144, 2));
          final angle =
              (math.atan2(y - 144, x - 150) * 180 / math.pi + 360) % 360;
          if (rgba.getUint32((y * image.width + x) * 4) == 0x39A7C2FF) {
            continue;
          }
          if ((radius - 80).abs() < 4 && angle > 60 && angle < 75) {
            rings++;
          }
          if ((radius > 88 && radius < 92) || (radius > 105 && radius < 108)) {
            dashes++;
          }
        }
      }
      image.dispose();
      return (rings, dashes);
    }))!;

    await tester.pumpWidget(preview(1, 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    final baseline = await countPixels();
    final controller = tester
        .widget<rive.RiveWidget>(find.byType(rive.RiveWidget))
        .controller;
    expect(baseline.$1, greaterThan(0));
    expect(baseline.$2, greaterThan(0));

    await tester.pumpWidget(preview(3, 1));
    await tester.pump();
    final thickRings = await countPixels();
    expect(thickRings.$1, greaterThan(baseline.$1));
    expect(thickRings.$2, baseline.$2);

    await tester.pumpWidget(preview(1, 3));
    await tester.pump();
    final thickDashes = await countPixels();
    expect(thickDashes.$1, baseline.$1);
    expect(thickDashes.$2, greaterThan(baseline.$2));
    expect(
      tester.widget<rive.RiveWidget>(find.byType(rive.RiveWidget)).controller,
      same(controller),
    );
  });
}
