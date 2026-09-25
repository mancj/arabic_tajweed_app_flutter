// Защищает автоматическое прослушивание вариантов: записи должны идти сверху
// вниз, заливка — повторять активную запись и очищаться в состоянии покоя.
import 'package:arabic_tajweed_app/app/pages/lesson/option_audio_sequence.dart';
import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/answer_option.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('варианты звучат по очереди и очищают прогресс карточек', () async {
    final audio = _ControlledAudio();
    final sequence = OptionAudioSequence(
      audio: audio,
      interOptionDelay: Duration.zero,
    );

    final playback = sequence.playAll(['first.mp3', 'second.mp3', 'third.mp3']);
    await pumpEventQueue();
    expect(audio.played, ['first.mp3']);

    audio.track.value = const AudioTrack(progress: .45, isPlaying: true);
    expect(sequence.state.value.activeIndex, 0);
    expect(sequence.state.value.progressAt(0), .45);

    audio.complete();
    await pumpEventQueue();
    expect(audio.played, ['first.mp3', 'second.mp3']);
    expect(sequence.state.value.progressAt(0), 0);

    audio.complete();
    await pumpEventQueue();
    expect(audio.played, ['first.mp3', 'second.mp3', 'third.mp3']);
    audio.complete();
    await playback;

    expect(sequence.state.value.activeIndex, isNull);
    expect(sequence.state.value.progress, [0, 0, 0]);
    sequence.dispose();
  });

  testWidgets('фон варианта заполняется на переданную долю', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnswerOption(playbackProgress: .4, child: Text('Звучание 1')),
      ),
    );
    await tester.pumpAndSettle();

    final fill = tester.widgetList<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.any((box) => box.widthFactor == .4), isTrue);
    final colors = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(colors.any((box) => box.color == UIColors.primary10), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('содержимое варианта остаётся по центру по вертикали', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AnswerOption(child: Text('Звучание 1')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.text('Звучание 1')).dy,
      closeTo(tester.getCenter(find.byType(AnswerOption)).dy, 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _ControlledAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  final played = <String>[];

  @override
  Future<void> playAsset(String? asset) async {
    if (asset == null) return;
    played.add(asset);
    track.value = const AudioTrack(isPlaying: true);
  }

  void complete() {
    track.value = const AudioTrack(progress: 1, isPlaying: false);
  }

  @override
  Future<void> stop() async => track.value = AudioTrack.silent;

  @override
  Future<void> toggleAsset(String? asset) => playAsset(asset);

  @override
  Future<void> dispose() async => track.dispose();
}
