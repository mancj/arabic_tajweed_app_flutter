// Временный харнесс: рендерит экран в PNG для визуальной сверки с макетом.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';

Future<void> loadAppFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;

  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  testWidgets('render', (tester) async {
    await loadAppFonts();

    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Get.put(AlphabetLetterController());

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(440, 1200),
          padding: EdgeInsets.only(top: 59, bottom: 34),
        ),
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          home: AlphabetLetterPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${Platform.environment['OUT'] ?? '/tmp'}/alphabet_letter.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
