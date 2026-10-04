// Повторные тапы должны менять весь набор выбора, а проверка — фиксировать
// ответ. При ожидании разрешения микрофона и HTTP нельзя подменить ожидаемый
// слог переключателем; unclear не должен выглядеть как учебная ошибка.
import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/debug/haraka_match_debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/debug/syllable_pronunciation_debug_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_match_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/segmented_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_pronunciation_exercise.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/pronunciation_checker.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_rest_client.dart';
import 'package:arabic_tajweed_app/data/rest/syllable_check.dart';
import 'package:arabic_tajweed_app/data/voice_recorder.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/haraka_test_content.dart';
import '../helpers/plugin_mocks.dart';

void main() {
  setUp(mockPlatformPlugins);
  tearDown(Get.reset);

  Future<void> mount(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GetMaterialApp(home: page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder option(String id) =>
      find.byKey(ValueKey('haraka-match-option-vowel.$id'));
  Set<String> selected(WidgetTester tester) => tester
      .widget<HarakaMatchExercise>(find.byType(HarakaMatchExercise))
      .selectedIds;

  testWidgets('несколько ответов, снятие выбора и блокировка после проверки', (
    tester,
  ) async {
    final audio = _Audio();
    await mount(
      tester,
      HarakaMatchDebugPage(audio: audio, syllables: harakaTestSyllables),
    );
    expect(audio.played, ['audio/harakat/ba_kasra.mp3']);
    expect(find.text('بِ'), findsNothing);
    expect(tester.widget<NextButton>(find.byType(NextButton)).enabled, isFalse);

    await tester.tap(find.byType(PlayControl));
    await tester.pump();
    expect(audio.toggled, ['audio/harakat/ba_kasra.mp3']);
    await tester.tap(option('mim.kasra'));
    await tester.pump();
    await tester.tap(option('mim.kasra'));
    await tester.pump();
    expect(selected(tester), isEmpty);
    await tester.tap(option('mim.kasra'));
    await tester.pump();
    await tester.tap(option('ra.kasra'));
    await tester.pump();
    expect(selected(tester), {'vowel.mim.kasra', 'vowel.ra.kasra'});
    await tester.tap(find.text('Проверить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Все подходящие слоги найдены'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getBottomLeft(find.text('Все подходящие слоги найдены')).dy,
      lessThan(tester.getTopLeft(find.byType(NextButton)).dy),
    );
    tester
        .widget<HarakaMatchExercise>(find.byType(HarakaMatchExercise))
        .onToggle('vowel.ba.fatha');
    await tester.pump();
    expect(selected(tester), {'vowel.mim.kasra', 'vowel.ra.kasra'});

    await tester.tap(find.text('Следующее задание'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(selected(tester), isEmpty);
    expect(audio.played, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('один верный ответ не засчитывает всю группу', (tester) async {
    await mount(
      tester,
      HarakaMatchDebugPage(audio: _Audio(), syllables: harakaTestSyllables),
    );
    await tester.tap(option('mim.kasra'));
    await tester.pump();
    await tester.tap(find.text('Проверить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Все подходящие слоги найдены'), findsNothing);
    expect(find.textContaining('Нужные слоги:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('слог фиксируется ещё до разрешения на микрофон', (tester) async {
    final recorder = _DelayedRecorder();
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final client = _Client(dio);
    final checker = PronunciationChecker(recorder: recorder, client: client);
    final audio = _Audio();
    await mount(
      tester,
      SyllablePronunciationDebugPage(
        checker: checker,
        audio: audio,
        syllables: harakaTestSyllables,
      ),
    );
    String glyph() => tester
        .widget<SyllablePronunciationExercise>(
          find.byType(SyllablePronunciationExercise),
        )
        .glyph;
    SegmentedTabs marks() => tester.widget<SegmentedTabs>(
      find.byWidgetPredicate(
        (widget) => widget is SegmentedTabs && widget.labels.contains('Касра'),
      ),
    );

    expect(glyph(), 'بَ');
    expect(find.byType(PlayControl), findsNothing);
    expect(audio.played, isEmpty);
    await tester.tap(find.byKey(const ValueKey('recorder-action')));
    await tester.pump();
    marks().onChanged(1);
    tester.widget<LetterTabs>(find.byType(LetterTabs)).onChanged(1);
    await tester.pump();
    expect(glyph(), 'بَ');
    expect(tester.takeException(), isNull);

    recorder.ready.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(checker.isRecording.value, isTrue);
    await tester.tap(find.byKey(const ValueKey('recorder-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(client.expected, 'بَ');
    marks().onChanged(2);
    await tester.pump();
    expect(glyph(), 'بَ');
    client.answer.complete(
      const SyllableCheck(
        expected: 'بَ',
        heard: null,
        status: SyllableCheckStatus.unclear,
        letterMatched: null,
        harakaMatched: null,
        hint: 'Повторите запись.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Повторите запись'), findsOneWidget);
    expect(find.text('Не удалось уверенно разобрать слог'), findsOneWidget);
    expect(find.text('Попробуйте ещё раз'), findsNothing);
    expect(find.text('Послушать образец'), findsOneWidget);

    marks().onChanged(1);
    await tester.pump();
    expect(glyph(), 'بِ');
    expect(checker.syllableResult.value, isNull);
    expect(find.text('Послушать образец'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);
  final played = <String?>[];
  final toggled = <String?>[];
  @override
  Future<void> playAsset(String? asset) async => played.add(asset);
  @override
  Future<void> toggleAsset(String? asset) async => toggled.add(asset);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => track.dispose();
}

class _DelayedRecorder extends VoiceRecorder {
  final ready = Completer<bool>();
  @override
  Future<bool> start() => ready.future;
  @override
  Future<File?> stop() async =>
      File('${Directory.systemTemp.path}/unused_syllable_test.m4a');
}

class _Client extends PronunciationRestClient {
  _Client(Dio dio) : super(dio: dio);
  final answer = Completer<SyllableCheck>();
  String? expected;
  @override
  Future<SyllableCheck> checkSyllable({
    required File audio,
    required String expected,
    CancelToken? cancelToken,
  }) {
    this.expected = expected;
    return answer.future;
  }
}
