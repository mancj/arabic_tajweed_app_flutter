import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadAppFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    // ignore: avoid_print
    print('FAMILY: ${family['family']} -> ${(family['fonts'] as List).length}');
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  testWidgets('probe', (tester) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(600, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(600, 200)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            child: ColoredBox(
            color: Color(0xFFFFFFFF),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('ج', style: TextStyle(fontFamily: 'Rubik', fontSize: 90, color: Color(0xFF000000))),
                Text('ج',
                    style: TextStyle(
                        fontFamily: 'Rubik',
                        fontVariations: [FontVariation('wght', 500)],
                        fontSize: 90, color: Color(0xFF000000))),
                Text('ج',
                    style: TextStyle(
                        fontFamily: 'ScheherazadeNew', fontSize: 90, color: Color(0xFF000000))),
                Text('Rq', style: TextStyle(fontFamily: 'Rubik', fontSize: 90, color: Color(0xFF000000))),
              ],
            ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${Platform.environment['OUT'] ?? '/tmp'}/font_probe.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
