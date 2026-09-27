// Защищает отладочную раскладку: активный слот звучит сам, его кнопку можно
// нажать повторно, а после выбора плитки звучит следующий слот.
import 'package:arabic_tajweed_app/app/pages/debug/haraka_sequence_debug_page.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('активный звуковой слот воспроизводится автоматически', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      MaterialApp(home: HarakaSequenceDebugPage(audio: audio)),
    );
    await tester.pump();
    expect(audio.played, ['audio/harakat/ba_fatha.mp3']);

    audio.complete();
    await tester.pump();
    await tester.tap(find.byTooltip('Прослушать звук 1'));
    await tester.pump();
    expect(audio.played, [
      'audio/harakat/ba_fatha.mp3',
      'audio/harakat/ba_fatha.mp3',
    ]);

    await tester.tap(find.byKey(const ValueKey('form-tile-debug.ba.fatha')));
    await tester.pumpAndSettle();
    expect(audio.played.last, 'audio/harakat/ba_kasra.mp3');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('после ошибки верная огласовка остаётся в слоте', (tester) async {
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      MaterialApp(home: HarakaSequenceDebugPage(audio: audio)),
    );
    await tester.pump();

    for (final id in ['debug.ba.damma', 'debug.ba.kasra', 'debug.ba.fatha']) {
      await tester.tap(find.byKey(ValueKey('form-tile-$id')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Правильно 1 из 3'), findsOneWidget);
    await tester.tap(find.text('Исправить'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-slot-sound-1')),
        matching: find.text('بِ'),
      ),
      findsOneWidget,
    );
    expect(audio.played.last, 'audio/harakat/ba_fatha.mp3');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _RecordingAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  final played = <String>[];

  @override
  Future<void> playAsset(String? asset) async {
    if (asset == null) return;
    played.add(asset);
    track.value = const AudioTrack(isPlaying: true);
  }

  void complete() => track.value = AudioTrack.silent;

  @override
  Future<void> stop() async => track.value = AudioTrack.silent;

  @override
  Future<void> toggleAsset(String? asset) => playAsset(asset);

  @override
  Future<void> dispose() async => track.dispose();
}
