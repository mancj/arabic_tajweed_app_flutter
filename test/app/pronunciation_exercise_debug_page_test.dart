import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/debug/pronunciation_exercise_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/pronunciation/pronunciation_controller.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/glow_wave_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Отладочный экран должен показывать ожидание без записи и сервера:
/// так можно увидеть анимацию, даже если проверка произношения недоступна.
void main() {
  testWidgets('ручной просмотр ожидания включает и выключает волну', (
    tester,
  ) async {
    final controller = Get.put(PronunciationController());
    controller.letters.value = [
      CurriculumLoader.parse(
        File('assets/curriculum/stage1.json').readAsStringSync(),
      ).baseLetters.first,
    ];
    addTearDown(() => Get.delete<PronunciationController>(force: true));

    await tester.pumpWidget(
      const GetMaterialApp(home: PronunciationExerciseDebugPage()),
    );
    expect(find.text('Назовите эту букву вслух'), findsOneWidget);
    expect(find.byType(PronunciationRecorderWidget), findsOneWidget);
    expect(find.byType(CircleButton), findsOneWidget);

    final show = find.text('Показать ожидание без сервера');
    await tester.ensureVisible(show);
    await tester.tap(show);
    await tester.pump();
    expect(find.byType(GlowWaveWidget), findsOneWidget);
    expect(find.byType(CircleButton), findsNothing);
    expect(find.text('Проверяем произношение'), findsOneWidget);

    final stop = find.text('Завершить ожидание');
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GlowWaveWidget), findsNothing);
    expect(find.byType(CircleButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
