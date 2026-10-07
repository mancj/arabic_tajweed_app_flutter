// Все места видны сразу; сначала выбираются формы, затем огласовки.
// Переходы автоматические, проверяется целое слово. Повтор сохраняет
// верные части, а быстрый повторный тап не заполняет соседнюю позицию.
// Проверяем настоящий контент, звук, доступность и маленький экран.
import 'package:arabic_tajweed_app/app/pages/debug/connection_build_debug_content.dart';
import 'package:arabic_tajweed_app/app/pages/debug/word_build_debug_page.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/connected_word_preview.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/exercise_tile.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/word_build_exercise.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/word_build_question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/plugin_mocks.dart';

void main() {
  setUp(mockPlatformPlugins);
  tearDown(Get.reset);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<_Audio> mount(
    WidgetTester tester, {
    List<WordBuildQuestion>? questions,
    bool animations = true,
    Size size = const Size(375, 812),
    bool wait = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final audio = _Audio();
    final content =
        questions ?? (await tester.runAsync(loadWordBuildDebugQuestions))!;
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: !animations),
          child: child!,
        ),
        home: WordBuildDebugPage(audio: audio, questions: content),
      ),
    );
    if (wait) await settle(tester);
    return audio;
  }

  WordBuildExercise state(WidgetTester tester) =>
      tester.widget(find.byType(WordBuildExercise));
  ConnectedWordPreview preview(WidgetTester tester) =>
      tester.widget(find.byType(ConnectedWordPreview));
  Finder form(String id) => find.byKey(ValueKey('word-build-form-$id'));
  Finder mark(String id) => find.byKey(ValueKey('word-build-mark-$id'));

  Future<void> choose(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> solveForms(WidgetTester tester) async {
    final question = state(tester).question;
    for (final step in question.steps) {
      await choose(tester, form(step.expectedFormId));
    }
  }

  Future<void> solveMarks(WidgetTester tester) async {
    final question = state(tester).question;
    for (final step in question.steps) {
      await choose(tester, mark(step.expectedMarkId));
    }
  }

  testWidgets('все места видны сразу, формы и знаки идут двумя проходами', (
    tester,
  ) async {
    final audio = await mount(tester);
    final semantics = tester.ensureSemantics();
    final question = state(tester).question;
    expect(question.display, 'كَتَبَ');
    expect(audio.played, [question.audioAsset]);
    expect(preview(tester).glyphs, [null, null, null]);
    expect(
      tester
          .widget<Row>(find.byKey(const ValueKey('word-build-preview')))
          .textDirection,
      TextDirection.rtl,
    );
    final gaps = [
      for (var i = 0; i < 3; i++) find.byKey(ValueKey('word-build-gap-$i')),
    ];
    expect(gaps.every((gap) => gap.evaluate().length == 1), isTrue);
    expect(
      tester.getCenter(gaps[0]).dx,
      greaterThan(tester.getCenter(gaps[1]).dx),
    );
    expect(
      tester.getCenter(gaps[1]).dx,
      greaterThan(tester.getCenter(gaps[2]).dx),
    );
    expect(
      find.bySemanticsLabel('Не заполнено букв: 3. Всего букв: 3'),
      findsOneWidget,
    );
    state(tester).onMarkSelected(question.steps.first.expectedMarkId);
    await settle(tester);
    expect(state(tester).markIds, [null, null, null]);

    for (final (i, step) in question.steps.indexed) {
      expect(state(tester).phase, WordBuildPhase.forms);
      expect(state(tester).activeIndex, i);
      expect(
        find.text('Выберите форму буквы «${step.letter.label}»'),
        findsOneWidget,
      );
      expect(find.byType(NextButton), findsNothing);
      expect(find.text('Проверить'), findsNothing);
      await choose(tester, form(step.expectedFormId));
      expect(preview(tester).glyphs.length, 3);
      expect(
        preview(tester).glyphs[i],
        step.preview(step.expectedFormId, null),
      );
      expect(state(tester).markIds, [null, null, null]);
      expect(state(tester).evaluation, isNull);
      expect(find.byKey(ValueKey('word-build-gap-$i')), findsNothing);
      expect(audio.played.length, i == 2 ? 2 : 1);
    }

    for (final (i, step) in question.steps.indexed) {
      expect(state(tester).phase, WordBuildPhase.marks);
      expect(state(tester).activeIndex, i);
      expect(
        find.text('Огласовка буквы «${step.letter.label}» по звуку'),
        findsOneWidget,
      );
      expect(find.byType(NextButton), findsNothing);
      await choose(tester, mark(step.expectedMarkId));
      expect(
        preview(tester).glyphs[i],
        step.preview(step.expectedFormId, step.expectedMarkId),
      );
      expect(state(tester).evaluation == null, i < 2);
      expect(audio.played.length, 2);
    }
    expect(state(tester).evaluation!.correct, isTrue);
    expect(find.byType(ExerciseChoiceTile), findsNothing);
    expect(find.text('Слово собрано правильно'), findsOneWidget);
    expect(find.bySemanticsLabel('كَتَبَ'), findsOneWidget);
    semantics.dispose();
    expect(find.text('Следующее слово'), findsOneWidget);
    expect(find.text('Следующая буква'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(audio.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('повторные нажатия и старые плитки не пропускают места', (
    tester,
  ) async {
    await mount(tester);
    final question = state(tester).question;
    final oldForm = state(tester).onFormSelected;
    oldForm(question.steps.first.expectedFormId);
    oldForm(question.steps.first.expectedFormId);
    await settle(tester);
    expect(state(tester).activeIndex, 1);
    expect(state(tester).formIds, [
      question.steps.first.expectedFormId,
      null,
      null,
    ]);
    for (final step in question.steps.skip(1)) {
      await choose(tester, form(step.expectedFormId));
    }
    final oldMark = state(tester).onMarkSelected;
    oldMark(question.steps.first.expectedMarkId);
    oldMark('haraka.kasra');
    await settle(tester);
    expect(state(tester).activeIndex, 1);
    expect(state(tester).markIds, [
      question.steps.first.expectedMarkId,
      null,
      null,
    ]);
    for (final step in question.steps.skip(1)) {
      await choose(tester, mark(step.expectedMarkId));
    }
    oldForm(question.steps.first.expectedFormId);
    oldMark('haraka.kasra');
    await settle(tester);
    expect(state(tester).evaluation!.correct, isTrue);
    final next = tester.widget<NextButton>(find.byType(NextButton)).onTap!;
    next();
    next();
    oldForm(question.steps.first.expectedFormId);
    oldMark('haraka.kasra');
    await settle(tester);
    expect(state(tester).question.display, 'كُتِبَ');
    expect(state(tester).activeIndex, 0);
    expect(state(tester).formIds, [null, null, null]);
    expect(state(tester).markIds, [null, null, null]);
    expect(preview(tester).glyphs, [null, null, null]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (wrongForm, wrongMark) in [
    (true, false),
    (false, true),
    (true, true),
  ]) {
    testWidgets(
      'повтор очищает только ошибочные части: форма=$wrongForm знак=$wrongMark',
      (tester) async {
        await mount(tester);
        final question = state(tester).question;
        final wrongFormId = question.steps[1].formOptions
            .firstWhere(
              (option) => option.id != question.steps[1].expectedFormId,
            )
            .id;
        for (final (i, step) in question.steps.indexed) {
          await choose(
            tester,
            form(i == 1 && wrongForm ? wrongFormId : step.expectedFormId),
          );
        }
        for (final (i, step) in question.steps.indexed) {
          await choose(
            tester,
            mark(i == 2 && wrongMark ? 'haraka.kasra' : step.expectedMarkId),
          );
        }
        final result = state(tester).evaluation!;
        expect(result.correct, isFalse);
        expect(result.formMistakes, wrongForm ? 1 : 0);
        expect(result.markMistakes, wrongMark ? 1 : 0);
        expect(
          preview(tester).glyphs[1],
          question.steps[1].preview(
            wrongForm ? wrongFormId : question.steps[1].expectedFormId,
            question.steps[1].expectedMarkId,
          ),
        );
        expect(find.text('Следующее слово'), findsNothing);
        final oldResult = state(tester);
        await tester.tap(find.text('Попробовать ещё раз'));
        await settle(tester);
        expect(state(tester).evaluation, isNull);
        expect(state(tester).formIds, [
          question.steps[0].expectedFormId,
          wrongForm ? null : question.steps[1].expectedFormId,
          question.steps[2].expectedFormId,
        ]);
        expect(state(tester).markIds, [
          question.steps[0].expectedMarkId,
          question.steps[1].expectedMarkId,
          wrongMark ? null : question.steps[2].expectedMarkId,
        ]);
        expect(
          oldResult.formIds[1],
          wrongForm ? wrongFormId : question.steps[1].expectedFormId,
        );
        if (wrongForm) {
          expect(state(tester).phase, WordBuildPhase.forms);
          expect(state(tester).activeIndex, 1);
          await choose(tester, form(question.steps[1].expectedFormId));
        }
        if (wrongMark) {
          expect(state(tester).phase, WordBuildPhase.marks);
          expect(state(tester).activeIndex, 2);
          expect(find.byType(NextButton), findsNothing);
          await choose(tester, mark(question.steps[2].expectedMarkId));
        }
        expect(state(tester).evaluation!.correct, isTrue);
        expect(preview(tester).glyphs, [
          for (final step in question.steps)
            step.preview(step.expectedFormId, step.expectedMarkId),
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('слова с разрывами и четырьмя буквами доступны на узком экране', (
    tester,
  ) async {
    final questions = (await tester.runAsync(loadWordBuildDebugQuestions))!;
    await mount(
      tester,
      questions: questions,
      size: const Size(320, 640),
      animations: false,
    );
    for (final question in questions) {
      expect(state(tester).question, same(question));
      for (final step in question.steps) {
        final rects = step.formOptions
            .map((option) => tester.getRect(form(option.id)))
            .toList();
        expect(
          rects.every((rect) => rect.width >= 44 && rect.height >= 44),
          isTrue,
        );
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i - 1].overlaps(rects[i]), isFalse);
        }
        await choose(tester, form(step.expectedFormId));
        expect(
          find.descendant(
            of: find.byType(ConnectedWordPreview),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await solveMarks(tester);
      expect(state(tester).evaluation!.correct, isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Следующее слово'));
      await settle(tester);
    }
    expect(state(tester).question, same(questions.first));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('при переходе и новом слове звучит именно текущее слово', (
    tester,
  ) async {
    final audio = await mount(tester);
    final first = state(tester).question;
    await solveForms(tester);
    await solveMarks(tester);
    await tester.tap(find.text('Следующее слово'));
    await settle(tester);
    final second = state(tester).question;
    expect(audio.played, [
      first.audioAsset,
      first.audioAsset,
      second.audioAsset,
    ]);
    await solveForms(tester);
    expect(audio.played.last, second.audioAsset);
    expect(audio.played.length, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('выход до автозвука отменяет отложенное воспроизведение', (
    tester,
  ) async {
    final audio = await mount(tester, wait: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(audio.played, isEmpty);
    expect(audio.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _Audio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier<AudioTrack>(
    AudioTrack.silent,
  );
  final played = <String?>[];
  bool disposed = false;

  @override
  Future<void> playAsset(String? asset) async => played.add(asset);
  @override
  Future<void> toggleAsset(String? asset) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    track.dispose();
  }
}
