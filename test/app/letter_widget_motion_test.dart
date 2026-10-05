// Карточка с выключенными системными анимациями должна успокоиться после
// появления. Иначе волна, вращение или датчики снова начнут постоянно рисовать
// экран. Узор не должен сменяться при выборе ответа и перестройке карточки.

import 'package:arabic_tajweed_app/app/widgets/ui_kit/animated_background_shapes.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('карточка без анимаций не запрашивает кадры в тишине', (
    tester,
  ) async {
    final track = ValueNotifier<AudioTrack>(AudioTrack.silent);
    addTearDown(track.dispose);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: LetterWidgetCard(
              letter: 'بَ',
              isArabic: true,
              onPlay: () {},
              autoPlay: false,
              track: track,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    track.value = const AudioTrack(isPlaying: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('перестройка сохраняет выбранные фоновые фигуры', (tester) async {
    Future<void> showShapes() {
      // Новый экземпляр вызывает перестройку, как новый выбранный ответ.
      // ignore: prefer_const_constructors
      final shapes = AnimatedBackgroundShapes();
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: SizedBox.square(dimension: 320, child: shapes),
            ),
          ),
        ),
      );
    }

    List<String> assets() => tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toList();

    await showShapes();
    final initial = assets();
    for (var rebuild = 0; rebuild < 8; rebuild++) {
      await showShapes();
      expect(assets(), initial);
    }
  });
}
