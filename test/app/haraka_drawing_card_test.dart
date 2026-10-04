// Защищает главное отличие письма огласовок: буква остаётся видимой,
// а общий холст проверяет положение знака относительно неё.
// На всех настоящих SVG знаку должно хватать места внутри холста:
// возврат большой опорной буквы или подъёма обрезал бы верхнюю огласовку.
import 'dart:convert';
import 'dart:io';

import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_drawing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('карточка оставляет букву под закреплённым холстом', (
    tester,
  ) async {
    final controller = DrawingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HarakaDrawingCard(
              letterId: 'ba',
              title: 'Нарисуйте огласовку',
              hint: 'По памяти',
              onClear: controller.clear,
              controller: controller,
              matcher: const TracingMatcher(),
              mode: TracingMode.freehand,
              shape: TracingShapes.arabicBa,
              enabled: true,
              missesBeforeReveal: 3,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
    final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    expect(canvas.mode, TracingMode.freehand);
    expect(canvas.placement, TracingPlacement.anchored);
    expect(canvas.placeholderOffset, Offset.zero);
    expect(canvas.strokeWidth, HarakaDrawingCard.strokeWidth);
    expect(canvas.bandScale, HarakaDrawingCard.bandScale);
    expect(canvas.bandScale, greaterThan(1.65));
  });

  testWidgets('огласовки всех букв помещаются в холст на узком экране', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DrawingController();
    addTearDown(controller.dispose);
    final letters = Directory('assets/svg/alphabet')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_base.svg'))
        .toList();
    for (final letter in letters) {
      rootBundle.evict(letter.path);
    }
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (data) async {
      final path = utf8.decode(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return ByteData.sublistView(File(path).readAsBytesSync());
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    for (final letter in letters) {
      final letterId = letter.uri.pathSegments.last.replaceAll('_base.svg', '');
      for (final sign in ['fatha', 'kasra', 'damma']) {
        final shape = TracingShapeSvg.parse(
          File('assets/svg/harakat/$sign.svg').readAsStringSync(),
          id: 'harakat/$sign',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HarakaDrawingCard(
                  letterId: letterId,
                  title: 'Нарисуйте огласовку',
                  hint: 'По памяти',
                  onClear: controller.clear,
                  controller: controller,
                  matcher: const TracingMatcher(),
                  mode: TracingMode.freehand,
                  shape: shape,
                  enabled: true,
                  missesBeforeReveal: 3,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
        expect(canvas.placeholder, isNotNull, reason: '$letterId / $sign');
        final size = tester.getSize(find.byType(DrawingCanvas));
        final resolved = canvas.placeholder!
            .resolve(size, padding: canvas.placeholderPadding)
            .transformed(1, canvas.placeholderOffset);
        final bounds = resolved.whole.bounds;
        final reason = '$letterId / $sign';
        expect(bounds.top, greaterThanOrEqualTo(4), reason: reason);
        expect(
          bounds.bottom,
          lessThanOrEqualTo(size.height - 4),
          reason: reason,
        );
        expect(bounds.left, greaterThanOrEqualTo(4), reason: reason);
        expect(bounds.right, lessThanOrEqualTo(size.width - 4), reason: reason);
      }
    }
  });
}
