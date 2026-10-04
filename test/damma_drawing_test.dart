// Одинаковые штрихи даммы должны давать один результат с контуром и без.
// Защищает от возврата более строгой проверки по памяти, в том числе
// от стирания полезной части рисунка до окончания знака.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_drawing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<Offset> _loop({
  double phase = 0,
  double radiusX = 9,
  double radiusY = 8,
}) => [
  for (var i = 0; i <= 64; i++)
    Offset(
      158 + radiusX * math.cos(phase + i / 64 * 2 * math.pi),
      49 + radiusY * math.sin(phase + i / 64 * 2 * math.pi),
    ),
];

const _tail = [
  Offset(167, 49),
  Offset(168, 57),
  Offset(164, 65),
  Offset(156, 72),
  Offset(141, 76),
];

void main() {
  final source = TracingShapeSvg.parse(
    File('assets/svg/harakat/damma.svg').readAsStringSync(),
    id: 'harakat/damma',
  );
  const matcher = TracingMatcher();
  final original = source
      .resolve(const Size(329, 323), padding: 0)
      .parts
      .single;
  final samples = matcher.sample(original);

  void loadAssets(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (data) async {
      final path = utf8.decode(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return ByteData.sublistView(File(path).readAsBytesSync());
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    for (final id in ['ba', 'kaf', 'alif_hamza_above']) {
      rootBundle.evict('assets/svg/alphabet/${id}_base.svg');
    }
  }

  Future<DrawingController> mount(
    WidgetTester tester,
    TracingMode mode, {
    String letterId = 'ba',
    TracingShape? shape,
  }) async {
    final controller = DrawingController(smoothing: 1, minDistance: 0);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HarakaDrawingCard(
              key: UniqueKey(),
              letterId: letterId,
              title: 'Нарисуйте огласовку',
              hint: 'Рисование',
              onClear: controller.clear,
              controller: controller,
              matcher: matcher,
              mode: mode,
              shape: shape ?? source,
              enabled: true,
              missesBeforeReveal: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  List<List<Offset>> place(WidgetTester tester, List<List<Offset>> lines) {
    final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
    final resolved = canvas.placeholder!
        .resolve(
          tester.getSize(find.byType(DrawingCanvas)),
          padding: canvas.placeholderPadding,
        )
        .transformed(1, canvas.placeholderOffset);
    final shift =
        resolved.whole.bounds.center - original.bounds.center * resolved.scale;
    return [
      for (final line in lines)
        [for (final point in line) point * resolved.scale + shift],
    ];
  }

  void draw(DrawingController controller, List<List<Offset>> lines) {
    for (final line in lines) {
      controller.startStroke(line.first);
      for (final point in line.skip(1)) {
        controller.extendStroke(point);
      }
      controller.endStroke();
    }
  }

  testWidgets('допуск даммы одинаков с контуром и без на разных буквах', (
    tester,
  ) async {
    loadAssets(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cases = {
      'образец': [samples],
      'петля с другим началом': [_loop(phase: -math.pi / 2), _tail],
      'обратное направление': [_loop().reversed.toList(), _tail],
      'сначала хвост': [_tail, _loop()],
      'одним штрихом': [
        [..._loop(), ..._tail],
      ],
      'широкая петля': [_loop(radiusX: 13), _tail],
      'высокая петля': [_loop(radiusY: 12), _tail],
      'неровная линия': [
        [
          for (final (i, point) in samples.indexed)
            point + Offset(6 * math.sin(i * .8), 6 * math.cos(i * .9)),
        ],
      ],
      'кружок': [_loop()],
      'черта': [
        [const Offset(142, 62), const Offset(169, 45)],
      ],
      'мазня': [
        [
          for (var i = 0; i < 100; i++)
            Offset(
              130 + (i * 17 % 60).toDouble(),
              30 + (i * 23 % 70).toDouble(),
            ),
        ],
      ],
    };
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final letter in ['ba', 'kaf', 'alif_hamza_above']) {
        for (final entry in cases.entries) {
          final results = <bool>[];
          for (final mode in [TracingMode.tracing, TracingMode.freehand]) {
            final controller = await mount(tester, mode, letterId: letter);
            draw(controller, place(tester, entry.value));
            results.add(controller.check().isMatch);
            await tester.pumpAndSettle();
          }
          expect(
            results.last,
            results.first,
            reason: '$letter / $width / ${entry.key}',
          );
          if (entry.key == 'образец' || entry.key == 'неровная линия') {
            expect(results, everyElement(isTrue), reason: entry.key);
          }
        }
      }
    }
  });

  testWidgets('полезный первый штрих даммы сохраняется в обоих режимах', (
    tester,
  ) async {
    loadAssets(tester);
    final results = <(bool, int)>[];
    for (final mode in [TracingMode.tracing, TracingMode.freehand]) {
      final controller = await mount(tester, mode);
      draw(
        controller,
        place(tester, [samples.sublist(0, samples.length ~/ 2)]),
      );
      final result = controller.check();
      results.add((result.isMatch, controller.strokes.length));
      await tester.pumpAndSettle();
    }
    expect(results.last, results.first);
    expect(results.first.$2, 1);
  });

  testWidgets('при обводке дамма далеко от контура не засчитывается', (
    tester,
  ) async {
    loadAssets(tester);
    final controller = await mount(tester, TracingMode.tracing);
    final lines = place(tester, [samples]);
    draw(controller, [
      for (final line in lines)
        [for (final point in line) point + const Offset(0, 150)],
    ]);
    expect(controller.check().isMatch, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('неровная дамма по памяти принимается в центре и по углам', (
    tester,
  ) async {
    loadAssets(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rough = [
      for (final (i, point) in samples.indexed)
        point + Offset(6 * math.sin(i * .8), 6 * math.cos(i * .9)),
    ];
    for (var position = 0; position < 5; position++) {
      final controller = await mount(tester, TracingMode.freehand);
      final line = place(tester, [rough]).single;
      final bounds = (Path()..addPolygon(line, false)).getBounds();
      final size = tester.getSize(find.byType(DrawingCanvas));
      final origins = [
        const Offset(16, 16),
        Offset(size.width - bounds.width - 16, 16),
        Offset(16, size.height - bounds.height - 16),
        Offset(
          size.width - bounds.width - 16,
          size.height - bounds.height - 16,
        ),
        Offset(
          (size.width - bounds.width) / 2,
          (size.height - bounds.height) / 2,
        ),
      ];
      final shift = origins[position] - bounds.topLeft;
      draw(controller, [
        [for (final point in line) point + shift],
      ]);
      expect(controller.check().isMatch, isTrue, reason: 'место $position');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('проверка скрытого контура включена только для даммы', (
    tester,
  ) async {
    loadAssets(tester);
    for (final sign in ['fatha', 'kasra', 'damma']) {
      final shape = TracingShapeSvg.parse(
        File('assets/svg/harakat/$sign.svg').readAsStringSync(),
        id: 'harakat/$sign',
      );
      await mount(tester, TracingMode.freehand, shape: shape);
      final canvas = tester.widget<DrawingCanvas>(find.byType(DrawingCanvas));
      expect(canvas.allowHiddenGuideMatch, sign == 'damma');
      expect(canvas.allowAnyPosition, sign == 'damma');
      expect(canvas.mode, TracingMode.freehand);
    }
  });
}
