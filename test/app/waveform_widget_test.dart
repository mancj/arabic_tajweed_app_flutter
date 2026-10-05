import 'package:arabic_tajweed_app/app/widgets/ui_kit/waveform_widget.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Волна не должна ломаться на дорожке без пиков: на вебе и десктопе
/// нативного разбора нет, и звучание там выражается только раскачкой.
/// В браузере волна должна прекращать запросы кадров в тишине, снова оживать
/// на play и отписываться от старой дорожки: иначе экран постоянно рисуется
/// на телефоне или перестаёт реагировать на звук после смены упражнения.
void main() {
  final levels = List.generate(60, (i) => (i % 7) / 6);

  Future<void> pumpWave(
    WidgetTester tester,
    ValueListenable<AudioTrack> track, {
    bool animateWhenIdle = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WaveformWidget(
          height: 50,
          track: track,
          animateWhenIdle: animateWhenIdle,
        ),
      ),
    ),
  );

  testWidgets('в тишине нет кадров, звук запускает волну снова', (
    tester,
  ) async {
    final track = ValueNotifier<AudioTrack>(AudioTrack.silent);
    addTearDown(track.dispose);
    await pumpWave(tester, track, animateWhenIdle: false);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    track.value = const AudioTrack(isPlaying: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);

    track.value = AudioTrack.silent;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    track.value = const AudioTrack(isPlaying: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('после смены дорожки слушает только новую', (tester) async {
    final oldTrack = ValueNotifier<AudioTrack>(AudioTrack.silent);
    final newTrack = ValueNotifier<AudioTrack>(AudioTrack.silent);
    addTearDown(oldTrack.dispose);
    addTearDown(newTrack.dispose);
    await pumpWave(tester, oldTrack, animateWhenIdle: false);
    await pumpWave(tester, newTrack, animateWhenIdle: false);
    await tester.pumpAndSettle();

    oldTrack.value = const AudioTrack(isPlaying: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    newTrack.value = const AudioTrack(isPlaying: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      () => newTrack.value = const AudioTrack(isPlaying: true, progress: .5),
      returnsNormally,
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('дорожка с пиками не роняет отрисовку', (tester) async {
    final track = ValueNotifier<AudioTrack>(AudioTrack.silent);
    await pumpWave(tester, track);

    track.value = AudioTrack(levels: levels, progress: 0.4, isPlaying: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    track.value = track.value.copyWith(progress: 1, isPlaying: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('дорожка без пиков только раскачивает волну', (tester) async {
    final track = ValueNotifier<AudioTrack>(const AudioTrack(isPlaying: true));
    await pumpWave(tester, track);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('строгое количество бугров и неподвижная высота', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WaveformWidget(
            height: 50,
            minBumps: 3,
            maxBumps: 3,
            restHeight: 1,
            loudHeight: 1,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  test('уровень берётся по позиции воспроизведения', () {
    const track = AudioTrack(levels: [0, 0.5, 1], progress: 1);
    expect(track.level, 1);
    expect(const AudioTrack(levels: [0, 0.5, 1]).level, 0);
    expect(AudioTrack.silent.level, 0);
  });
}
