// Выбор огласовки автоматически проверяет обе части, только после выбора
// буквы, и блокирует дальнейшие изменения. При открытии огласовок повторяется
// исходный слог с начала; смена буквы не запускает звук. Разбор показывает
// отдельные ошибки; три варианта должны помещаться на телефоне.
// Появление по очереди запускается для нового задания и новой палитры,
// но не при каждом выборе; системное отключение анимаций убирает задержки.
import 'package:arabic_tajweed_app/app/pages/debug/syllable_build_debug_page.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/exercise_tile.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_build_exercise.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/haraka_test_content.dart';
import '../helpers/plugin_mocks.dart';

void main() {
  final pool = [
    ...harakaTestSyllables,
    for (final (id, glyph) in [('zay', 'ز'), ('dal', 'د')])
      ...HarakaSyllables.completeFamily(
        Atom(
          id: '$id.isolated',
          kind: AtomKind.letterForm,
          letterId: id,
          display: glyph,
        ),
        const [],
      ),
  ];
  setUp(mockPlatformPlugins);
  tearDown(Get.reset);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> entranceFrames(WidgetTester tester) async {
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<_Audio> mount(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    bool waitForEntrance = true,
    bool disableAnimations = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final audio = _Audio();
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: SyllableBuildDebugPage(audio: audio, syllables: pool),
      ),
    );
    if (waitForEntrance) {
      await settle(tester);
    } else {
      await tester.pump();
      await tester.pump();
    }
    return audio;
  }

  Finder letter(String id) => find.byKey(ValueKey('syllable-build-letter-$id'));
  Finder mark(String id) =>
      find.byKey(ValueKey('syllable-build-mark-haraka.$id'));
  SyllableBuildExercise state(WidgetTester tester) =>
      tester.widget<SyllableBuildExercise>(find.byType(SyllableBuildExercise));
  ExerciseChoiceTile option(WidgetTester tester, Finder choice) =>
      tester.widget<ExerciseChoiceTile>(
        find.descendant(of: choice, matching: find.byType(ExerciseChoiceTile)),
      );
  double opacity(WidgetTester tester, Finder choice) => tester
      .widget<FadeTransition>(
        find.descendant(of: choice, matching: find.byType(FadeTransition)),
      )
      .opacity
      .value;
  NextButton next(WidgetTester tester) =>
      tester.widget<NextButton>(find.byType(NextButton));

  Future<void> choose(WidgetTester tester, Finder choice) async {
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await settle(tester);
  }

  testWidgets('выбор огласовки автоматически проверяет всю сборку', (
    tester,
  ) async {
    final audio = await mount(tester);
    expect(audio.played, ['audio/harakat/ra_kasra.mp3']);
    expect(find.text('رِ'), findsNothing);
    expect(mark('kasra'), findsNothing);
    expect(find.byType(NextButton), findsNothing);
    expect(find.text('Проверить'), findsNothing);
    state(tester).onMarkSelected('haraka.kasra');
    await settle(tester);
    expect(state(tester).selectedMarkId, isNull);

    await choose(tester, letter('zay'));
    expect(audio.played, [
      'audio/harakat/ra_kasra.mp3',
      'audio/harakat/ra_kasra.mp3',
    ]);
    expect(audio.toggled, isEmpty);
    expect(find.text('ز'), findsWidgets);
    expect(mark('kasra'), findsOneWidget);
    expect(find.byType(NextButton), findsNothing);
    expect(state(tester).evaluation, isNull);

    await choose(tester, letter('ra'));
    expect(state(tester).selectedMarkId, isNull);
    expect(audio.played, hasLength(2));
    await tester.ensureVisible(find.byType(PlayControl));
    await tester.tap(find.byType(PlayControl));
    await settle(tester);
    expect(audio.toggled, ['audio/harakat/ra_kasra.mp3']);

    await choose(tester, mark('kasra'));
    expect(find.text('Слог собран правильно'), findsOneWidget);
    expect(state(tester).evaluation!.correct, isTrue);
    expect(next(tester).enabled, isTrue);
    expect(find.text('Проверить'), findsNothing);
    state(tester).onLetterSelected('dal');
    state(tester).onMarkSelected('haraka.fatha');
    await settle(tester);
    expect(state(tester).selectedLetterId, 'ra');
    expect(state(tester).selectedMarkId, 'haraka.kasra');
    expect(option(tester, letter('ra')).onTap, isNull);
    expect(audio.played, hasLength(2));
    expect(
      tester.getBottomLeft(find.text('Слог собран правильно')).dy,
      lessThan(tester.getTopLeft(find.byType(NextButton)).dy),
    );

    await tester.tap(find.text('Следующее задание'));
    await settle(tester);
    expect(state(tester).selectedLetterId, isNull);
    expect(state(tester).selectedMarkId, isNull);
    expect(state(tester).evaluation, isNull);
    expect(find.byType(NextButton), findsNothing);
    expect(audio.played, hasLength(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (letterId, markId, title) in [
    ('ra', 'fatha', 'Буква верная, огласовка отличается'),
    ('zay', 'kasra', 'Огласовка верная, буква отличается'),
    ('dal', 'damma', 'Буква и огласовка отличаются'),
  ]) {
    testWidgets('разбор: $title', (tester) async {
      await mount(tester);
      await choose(tester, letter(letterId));
      await choose(tester, mark(markId));
      expect(find.text('Проверить'), findsNothing);
      expect(find.text(title), findsOneWidget);
      expect(
        option(tester, letter(letterId)).accent,
        letterId == 'ra' ? UIColors.success : UIColors.error,
      );
      expect(
        option(tester, mark(markId)).accent,
        markId == 'kasra' ? UIColors.success : UIColors.error,
      );
      expect(find.textContaining('В записи звучит رِ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('три глифа помещаются на узком экране', (tester) async {
    await mount(tester, size: const Size(320, 640));
    await choose(tester, letter('ra'));
    await choose(tester, mark('kasra'));
    final choices = [letter('ra'), letter('zay'), letter('dal')];
    final rects = choices.map(tester.getRect).toList();
    expect(rects[0].overlaps(rects[1]), isFalse);
    expect(rects[1].overlaps(rects[2]), isFalse);
    expect(
      rects.every((rect) => rect.width >= 44 && rect.height >= 44),
      isTrue,
    );
    expect(find.text('رِ'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('плитки появляются по очереди и не исчезают при выборе', (
    tester,
  ) async {
    await mount(tester, waitForEntrance: false);
    await entranceFrames(tester);
    expect(opacity(tester, letter('ra')), greaterThan(0));
    expect(
      opacity(tester, letter('ra')),
      greaterThan(opacity(tester, letter('zay'))),
    );
    expect(opacity(tester, letter('dal')), 0);
    await settle(tester);

    await tester.tap(letter('ra'));
    await tester.pump();
    expect(opacity(tester, letter('ra')), 1);
    expect(opacity(tester, letter('zay')), 1);
    expect(opacity(tester, mark('damma')), 0);
    await tester.pump();
    await entranceFrames(tester);
    expect(
      opacity(tester, mark('fatha')),
      greaterThan(opacity(tester, mark('kasra'))),
    );
    await settle(tester);

    await tester.tap(letter('zay'));
    await tester.pump();
    expect(opacity(tester, letter('zay')), 1);
    expect(opacity(tester, mark('kasra')), 1);
    await settle(tester);
    await choose(tester, mark('kasra'));
    await tester.tap(find.text('Следующее задание'));
    await tester.pump();
    final newLetters = find.byType(ExerciseChoiceTile);
    expect(newLetters, findsNWidgets(3));
    expect(opacity(tester, newLetters.at(2)), 0);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('при отключённых анимациях все плитки видны сразу', (
    tester,
  ) async {
    await mount(tester, waitForEntrance: false, disableAnimations: true);
    expect(find.byType(ExerciseChoiceTile), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(ExerciseChoiceTile),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await tester.tap(letter('ra'));
    await tester.pump();
    expect(find.byType(ExerciseChoiceTile), findsNWidgets(6));
    expect(
      find.descendant(
        of: find.byType(ExerciseChoiceTile),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await settle(tester);
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
