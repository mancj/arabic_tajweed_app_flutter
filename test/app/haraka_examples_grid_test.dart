// Защищает интерактивную сетку: все примеры должны быть видны и каждый
// должен оставаться отдельной кнопкой воспроизведения.
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_examples_grid.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('каждый пример огласовки воспроизводится отдельно', (
    tester,
  ) async {
    final track = ValueNotifier(AudioTrack.silent);
    addTearDown(track.dispose);
    final fatha = [_example('ba.fatha', 'بَ')];
    final kasra = [_example('ta.kasra', 'تِ')];
    final damma = [_example('kaf.damma', 'كُ')];
    final summary = [_example('mim.fatha', 'مَ')];
    final examples = [...fatha, ...kasra, ...damma, ...summary];
    final played = <Atom>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: HarakaExamplesOverview(
                fathaExamples: fatha,
                kasraExamples: kasra,
                dammaExamples: damma,
                summaryExamples: summary,
                onPlay: played.add,
                track: track,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Фатха  َ'), findsOneWidget);
    expect(find.textContaining('краткий звук «а»'), findsOneWidget);
    expect(find.text('Касра  ِ'), findsOneWidget);
    expect(find.textContaining('краткий звук «и»'), findsOneWidget);
    expect(find.text('Дамма  ُ'), findsOneWidget);
    expect(find.textContaining('краткий звук «у»'), findsOneWidget);
    expect(find.text('Все вместе'), findsOneWidget);

    for (final example in examples) {
      expect(find.text(example.display), findsOneWidget);
      await tester.ensureVisible(find.text(example.display));
      await tester.tap(find.text(example.display));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(played, examples);
  });
}

Atom _example(String id, String display) => Atom(
  id: id,
  kind: AtomKind.syllable,
  display: display,
  audioAsset: 'audio/$id.mp3',
);
