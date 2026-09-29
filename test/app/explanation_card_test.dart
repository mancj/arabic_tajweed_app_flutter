// Защищает нативную сборку карточки: Markdown сохраняет вложенное выделение,
// блоки идут в авторском порядке, а несколько примеров делят один плеер.
import 'dart:io';

import 'package:arabic_tajweed_app/app/widgets/ui_kit/explanation_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_examples_grid.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_forms_overview.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/data/explanation_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/plugin_mocks.dart';

void main() {
  setUp(mockPlatformPlugins);

  testWidgets('все блоки помещаются в узкую карточку в порядке YAML', (
    tester,
  ) async {
    final content = ExplanationLoader.parse(
      File('assets/explanations/ru/ba.yaml').readAsStringSync(),
    );
    final track = ValueNotifier(AudioTrack.silent);
    addTearDown(track.dispose);
    final played = <Atom>[];
    await tester.pumpWidget(
      _host(
        ExplanationCard(
          content: content,
          onPlay: played.add,
          hasVoice: (atom) => atom.audioAsset != null,
          track: track,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(played, isEmpty);
    expect(find.byType(RuleCard), findsNWidgets(4));
    expect(find.byType(LetterWidgetCard), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(LetterWidgetCard),
        matching: find.byType(RuleCard),
      ),
      findsNothing,
    );
    expect(find.text('Буква Ба'), findsOneWidget);
    final makhraj = find.widgetWithText(RuleCard, 'Как произнести');
    final sifat = find.widgetWithText(RuleCard, 'Как звучит');
    expect(makhraj, findsOneWidget);
    expect(sifat, findsOneWidget);
    expect(
      tester.getTopLeft(makhraj).dy,
      greaterThan(tester.getTopLeft(find.byType(LetterWidgetCard)).dy),
    );
    expect(
      tester.getTopLeft(sifat).dy,
      greaterThan(tester.getTopLeft(makhraj).dy),
    );
    expect(find.byType(LetterFormsOverview), findsOneWidget);
    expect(find.byType(HighlightedWord), findsWidgets);
    final forms = tester
        .widget<LetterFormsOverview>(find.byType(LetterFormsOverview))
        .forms;
    expect(forms[1].example?.word, 'بات');
    final word = tester
        .widgetList<HighlightedWord>(find.byType(HighlightedWord))
        .singleWhere((item) => item.fontSize == 48);
    expect((word.word, word.index, word.form), ('بات', 0, LetterForm.initial));
    expect(find.text('Звук буквы'), findsOneWidget);
    expect(find.text('Фатха'), findsOneWidget);
    final ordered = [
      find.byType(LetterWidgetCard),
      find.byType(LetterFormsOverview),
      find.byType(HarakaExamplesGrid),
    ];
    for (var i = 1; i < ordered.length; i++) {
      expect(
        tester.getTopLeft(ordered[i]).dy,
        greaterThan(tester.getTopLeft(ordered[i - 1]).dy),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Буква с узором и кнопкой звучания всегда занимает собственную карточку;
  // правило остаётся отдельным даже когда letter стоит первым в YAML.
  testWidgets('буква курса стоит перед отдельной карточкой правила', (
    tester,
  ) async {
    final content = ExplanationLoader.parse(
      File('assets/explanations/ru/alif.isolated.yaml').readAsStringSync(),
    );
    final track = ValueNotifier(AudioTrack.silent);
    addTearDown(track.dispose);
    await tester.pumpWidget(
      _host(
        ExplanationCard(
          content: content,
          onPlay: (_) {},
          hasVoice: (atom) => atom.audioAsset != null,
          track: track,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final letter = find.byType(LetterWidgetCard);
    final rule = find.byType(RuleCard);
    expect(letter, findsOneWidget);
    expect(rule, findsNWidgets(3));
    expect(
      tester.getTopLeft(letter).dy,
      lessThan(tester.getTopLeft(rule.first).dy),
    );
    expect(find.ancestor(of: letter, matching: rule), findsNothing);
    expect(find.text('Алиф — ا'), findsOneWidget);
    expect(find.textContaining('Алиф удлиняет звук'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Иллюстрация из Markdown остаётся ассетом приложения и обрезается по
  // скруглённым краям, даже когда находится внутри RuleCard.
  testWidgets('изображение Markdown имеет скруглённые углы', (tester) async {
    final content = ExplanationLoader.parse(
      File('assets/explanations/ru/ba.isolated.yaml').readAsStringSync(),
    );
    final track = ValueNotifier(AudioTrack.silent);
    addTearDown(track.dispose);
    await tester.pumpWidget(
      _host(
        ExplanationCard(
          content: content,
          onPlay: (_) {},
          hasVoice: (_) => false,
          track: track,
        ),
      ),
    );
    final image = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/img/ba-makhraj.jpg',
    );
    expect(image, findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(RuleCard, 'Как произнести'),
        matching: image,
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: image,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ClipRRect &&
              widget.borderRadius == BorderRadius.circular(16),
        ),
      ),
      findsOneWidget,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('жирный и курсив сочетаются, ссылки передаются экрану', (
    tester,
  ) async {
    final content = ExplanationLoader.parse('''
title: Форматирование
blocks:
  - text: |
      **Жирный** и *Курсив* и ***Вместе***

      [Подробнее](https://example.com/lesson)

      - Первый пункт
      - Второй пункт
''');
    final track = ValueNotifier(AudioTrack.silent);
    addTearDown(track.dispose);
    final links = <String?>[];
    await tester.pumpWidget(
      _host(
        ExplanationCard(
          content: content,
          onPlay: (_) {},
          hasVoice: (_) => false,
          track: track,
          onTapLink: (_, href, _) => links.add(href),
        ),
      ),
    );
    final spans = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((widget) => _effectiveSpans(widget.text));
    expect(
      spans.any(
        (span) =>
            span.text == 'Жирный' && span.style?.fontWeight == FontWeight.bold,
      ),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.text == 'Курсив' && span.style?.fontStyle == FontStyle.italic,
      ),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.text == 'Вместе' &&
            span.style?.fontWeight == FontWeight.bold &&
            span.style?.fontStyle == FontStyle.italic,
      ),
      isTrue,
    );
    expect(find.text('Первый пункт', findRichText: true), findsOneWidget);
    expect(find.text('Второй пункт', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Подробнее', findRichText: true));
    expect(links, ['https://example.com/lesson']);
  });

  testWidgets('звук переключается между блоками, немые примеры не нажимаются', (
    tester,
  ) async {
    final content = ExplanationLoader.parse('''
title: Звучание
blocks:
  - examples: [{glyph: بَ, audio: audio/harakat/ba_fatha.mp3}]
  - examples:
      - {glyph: بِ, audio: audio/harakat/ba_kasra.mp3}
      - {glyph: ا}
  - sound: {label: Имя буквы, audio: audio/alphabet/ba.wav}
''');
    final track = ValueNotifier(AudioTrack.silent);
    addTearDown(track.dispose);
    final played = <String>[];
    await tester.pumpWidget(
      _host(
        ExplanationCard(
          content: content,
          onPlay: (atom) {
            played.add(atom.id);
            track.value = const AudioTrack(isPlaying: true);
          },
          hasVoice: (atom) => atom.audioAsset != null,
          track: track,
        ),
      ),
    );
    await tester.tap(find.text('بَ'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(played, ['card.0.example.0']);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    await tester.tap(find.text('بِ'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(played, ['card.0.example.0', 'card.1.example.0']);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    final grids = tester.widgetList<HarakaExamplesGrid>(
      find.byType(HarakaExamplesGrid),
    );
    expect(grids.every((grid) => grid.activeId == 'card.1.example.0'), isTrue);
    await tester.tap(find.text('ا'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
    expect(played, hasLength(2));
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await tester.ensureVisible(find.byType(PlayControl));
    await tester.tap(find.byType(PlayControl));
    await tester.pump(const Duration(milliseconds: 150));
    expect(played.last, 'card.2.sound');
  });
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 320, child: child)),
  ),
);

Iterable<TextSpan> _effectiveSpans(InlineSpan span, [TextStyle? parent]) sync* {
  if (span is! TextSpan) return;
  final style = parent?.merge(span.style) ?? span.style;
  yield TextSpan(text: span.text, style: style);
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _effectiveSpans(child, style);
  }
}
