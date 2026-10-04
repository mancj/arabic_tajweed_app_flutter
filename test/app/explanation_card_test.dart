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
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
    expect(find.byType(RuleCard), findsNWidgets(5));
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
    final writing = find.widgetWithText(RuleCard, 'Как пишется');
    expect(writing, findsOneWidget);
    expect(makhraj, findsOneWidget);
    expect(sifat, findsOneWidget);
    expect(
      tester.getTopLeft(writing).dy,
      greaterThan(tester.getTopLeft(find.byType(LetterWidgetCard)).dy),
    );
    expect(
      tester.getTopLeft(makhraj).dy,
      greaterThan(tester.getTopLeft(writing).dy),
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

  // Учебный образец с кнопкой звучания занимает собственную карточку;
  // написание не должно вернуться внутрь разбора при изменении компоновки.
  testWidgets('разбор, написание, махрадж и сыфат идут отдельными разделами', (
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
    expect(rule, findsNWidgets(4));
    final sections = tester.widgetList<RuleCard>(rule).toList();
    expect(sections.map((section) => section.title), [
      'Разбор',
      'Как пишется',
      'Как произнести',
      'Как звучит',
    ]);
    expect(sections.map((section) => section.sectionNumber), [
      '01',
      '02',
      '03',
      '04',
    ]);
    for (var index = 1; index < sections.length; index++) {
      expect(
        tester.getTopLeft(rule.at(index)).dy,
        greaterThan(tester.getTopLeft(rule.at(index - 1)).dy),
      );
    }
    final writingText = find.textContaining('вертикальная черта без точек');
    expect(
      find.descendant(of: rule.at(1), matching: writingText),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rule.first, matching: writingText),
      findsNothing,
    );
    expect(
      tester.getTopLeft(letter).dy,
      lessThan(tester.getTopLeft(rule.first).dy),
    );
    expect(find.ancestor(of: letter, matching: rule), findsNothing);
    expect(find.text('Алиф — ا'), findsOneWidget);
    expect(find.textContaining('в начале слова «арбуз»'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Иллюстрация из Markdown остаётся ассетом приложения и обрезается по
  // скруглённым краям, даже когда находится внутри RuleCard. Ограничения
  // Markdown не должны сжимать квадратную картинку или сужать её контейнер.
  testWidgets('изображение Markdown сохраняет пропорции и скругление', (
    tester,
  ) async {
    final content = ExplanationLoader.parse(
      File('assets/explanations/ru/hha.isolated.yaml').readAsStringSync(),
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
          (widget.image as AssetImage).assetName == 'assets/img/ha-makhraj.jpg',
    );
    expect(image, findsOneWidget);
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(image).image,
        tester.element(image),
      ),
    );
    await tester.pump();
    final imageSize = tester.getSize(image);
    final markdown = find.ancestor(
      of: image,
      matching: find.byType(MarkdownBody),
    );
    expect(imageSize.width, tester.getSize(markdown).width);
    expect(imageSize.height, closeTo(imageSize.width, 0.01));
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

  // При объединении названия с первым образцом легко потерять заголовок
  // документа, состоящего только из букв, или сломать длинное слово при 2×.
  testWidgets(
    'образец сохраняет название и помещает слово при крупном тексте',
    (tester) async {
      final track = ValueNotifier(AudioTrack.silent);
      addTearDown(track.dispose);
      for (final blocks in [
        '  - letter: {glyph: ا}',
        '  - letter: {glyph: دَرَسَ}\n  - text: Прочитайте слово целиком.',
      ]) {
        final content = ExplanationLoader.parse(
          'title: Учимся читать длинное слово\nblocks:\n$blocks',
        );
        await tester.pumpWidget(
          _host(
            MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: ExplanationCard(
                content: content,
                onPlay: (_) => fail('У образца без записи нет воспроизведения'),
                hasVoice: (_) => false,
                track: track,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Учимся читать длинное слово'), findsOneWidget);
        expect(find.byType(PlayControl), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  // У средней формы четыре черты соединения: подсчёт всех символов
  // ошибочно отправлял одну букву в широкий режим, как длинное слово.
  testWidgets(
    'соединённые формы компактны, узкий экран и крупный текст безопасны',
    (tester) async {
      final track = ValueNotifier(AudioTrack.silent);
      addTearDown(track.dispose);
      for (final (asset, width, scale, compact) in [
        ('ta.initial', 361.0, 1.0, true),
        ('ta.medial', 361.0, 1.0, true),
        ('ta.finalForm', 361.0, 1.0, true),
        ('ta.medial', 280.0, 1.0, false),
        ('ta.medial', 361.0, 2.0, false),
        ('word.darasa', 361.0, 1.0, false),
      ]) {
        final content = ExplanationLoader.parse(
          File('assets/explanations/ru/$asset.yaml').readAsStringSync(),
        );
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: ExplanationCard(
                    content: content,
                    onPlay: (_) {},
                    hasVoice: (_) => false,
                    track: track,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heading = tester.getRect(find.text(content.document.title));
        final specimen = find.byType(LetterWidgetCard);
        final glyphText = tester.widget<LetterWidgetCard>(specimen).letter;
        final glyph = tester.getRect(
          find.descendant(of: specimen, matching: find.text(glyphText)),
        );
        if (compact) {
          expect(glyph.left, greaterThan(heading.right), reason: asset);
          expect(glyph.top, lessThan(heading.bottom), reason: asset);
        } else {
          expect(
            glyph.top,
            greaterThanOrEqualTo(heading.bottom),
            reason: asset,
          );
        }
        expect(tester.takeException(), isNull, reason: asset);
      }
    },
  );

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

  // В уроке и справочнике onTapLink не передают: источник из YAML всё равно
  // должен открываться во внешнем браузере при нажатии.
  testWidgets('ссылка в объяснении открывается без обработчика экрана', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? launch;
    messenger.setMockMethodCallHandler(channel, (call) async {
      launch = call;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final content = ExplanationLoader.parse('''
title: Буква
blocks:
  - text: '[Источник](https://example.com/lesson)'
''');
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

    await tester.tap(find.text('Источник', findRichText: true));
    await tester.pump();
    expect(launch?.method, 'launch');
    expect(launch?.arguments['url'], 'https://example.com/lesson');
    expect(launch?.arguments['useWebView'], isFalse);
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
