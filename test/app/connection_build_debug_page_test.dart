// Переход формы → огласовки должен повторять исходный звук, а последний
// выбор — сразу проверять ответ. После ошибки сохраняется только верная
// часть; новый ответ нельзя затереть быстрым повторным нажатием.
// Проверяем реальные примеры во всех трёх позициях, RTL-пропуск, узкий
// экран и появление общих плиток без запуска планировщика или базы курса.
import 'package:arabic_tajweed_app/app/pages/debug/connection_build_debug_content.dart';
import 'package:arabic_tajweed_app/app/pages/debug/connection_build_debug_page.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/connection_build_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/exercise_tile.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
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
    List<ConnectionBuildQuestion>? questions,
    Size size = const Size(375, 812),
    bool animations = true,
    bool wait = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final audio = _Audio();
    final content =
        questions ??
        (await tester.runAsync(loadConnectionBuildDebugQuestions))!;
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: !animations),
          child: child!,
        ),
        home: ConnectionBuildDebugPage(audio: audio, questions: content),
      ),
    );
    if (wait) await settle(tester);
    return audio;
  }

  ConnectionBuildExercise state(WidgetTester tester) =>
      tester.widget(find.byType(ConnectionBuildExercise));
  Finder form(String id) => find.byKey(ValueKey('connection-build-form-$id'));
  Finder mark(String id) => find.byKey(ValueKey('connection-build-mark-$id'));

  Future<void> choose(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  ExerciseChoiceTile tile(WidgetTester tester, Finder finder) => tester.widget(
    find.descendant(of: finder, matching: find.byType(ExerciseChoiceTile)),
  );

  testWidgets('форма открывает знаки и повторяет звук, знак сразу проверяет', (
    tester,
  ) async {
    final audio = await mount(tester);
    final question = state(tester).question;
    expect(audio.played, [question.audioAsset]);
    expect(find.byType(ExerciseChoiceTile), findsNWidgets(3));
    expect(find.byKey(const ValueKey('connection-build-gap')), findsOneWidget);
    expect(find.text('Проверить'), findsNothing);
    final prompt = tester.widget<Text>(
      find.byKey(const ValueKey('connection-build-preview')),
    );
    expect(prompt.textDirection, TextDirection.rtl);
    state(tester).onMarkSelected(question.expectedMarkId);
    expect(state(tester).selectedMarkId, isNull);

    await choose(tester, form(question.expectedFormId));
    expect(audio.played, [question.audioAsset, question.audioAsset]);
    expect(find.byType(ExerciseChoiceTile), findsNWidgets(6));
    expect(find.byKey(const ValueKey('connection-build-gap')), findsNothing);
    final other = question.formOptions
        .firstWhere((atom) => atom.id != question.expectedFormId)
        .id;
    await choose(tester, form(other));
    expect(audio.played, hasLength(2));
    final shown = tester
        .widget<Text>(find.byKey(const ValueKey('connection-build-preview')))
        .textSpan!
        .toPlainText();
    expect(shown, question.preview(other, null).join('\u200c'));
    await choose(tester, form(question.expectedFormId));
    await choose(tester, mark(question.expectedMarkId));
    expect(state(tester).evaluation!.correct, isTrue);
    expect(find.text('Соединение собрано правильно'), findsOneWidget);
    expect(
      tile(tester, form(question.expectedFormId)).accent,
      UIColors.success,
    );
    final previousCallback = state(tester).onFormSelected;
    previousCallback(other);
    state(tester).onMarkSelected('haraka.damma');
    await settle(tester);
    expect(state(tester).selectedFormId, question.expectedFormId);
    expect(state(tester).selectedMarkId, question.expectedMarkId);
    expect(tile(tester, form(other)).onTap, isNull);

    await tester.tap(find.text('Следующее задание'));
    await settle(tester);
    expect(state(tester).selectedFormId, isNull);
    expect(state(tester).selectedMarkId, isNull);
    expect(state(tester).evaluation, isNull);
    expect(audio.played.last, state(tester).question.audioAsset);
    expect(find.byType(NextButton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(audio.disposed, isTrue);
  });

  for (final wrongForm in [true, false]) {
    testWidgets(
      'повтор сохраняет верную ${wrongForm ? 'огласовку' : 'форму'}',
      (tester) async {
        await mount(tester);
        final question = state(tester).question;
        final chosenForm = wrongForm
            ? question.formOptions
                  .firstWhere((atom) => atom.id != question.expectedFormId)
                  .id
            : question.expectedFormId;
        final chosenMark = wrongForm ? question.expectedMarkId : 'haraka.damma';
        await choose(tester, form(chosenForm));
        await choose(tester, mark(chosenMark));
        expect(state(tester).evaluation!.correct, isFalse);
        expect(
          find.text(
            wrongForm
                ? 'Огласовка верная, форма отличается'
                : 'Форма верная, огласовка отличается',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Попробовать ещё раз'));
        await settle(tester);
        expect(
          state(tester).selectedFormId,
          wrongForm ? null : question.expectedFormId,
        );
        expect(
          state(tester).selectedMarkId,
          wrongForm ? question.expectedMarkId : null,
        );
        await choose(
          tester,
          wrongForm
              ? form(question.expectedFormId)
              : mark(question.expectedMarkId),
        );
        expect(state(tester).evaluation!.correct, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('две ошибки очищают обе части без изменения готовых соседей', (
    tester,
  ) async {
    await mount(tester);
    final question = state(tester).question;
    await choose(
      tester,
      form(
        question.formOptions
            .firstWhere((atom) => atom.id != question.expectedFormId)
            .id,
      ),
    );
    await choose(tester, mark('haraka.damma'));
    expect(find.text('Форма и огласовка отличаются'), findsOneWidget);
    await tester.tap(find.text('Попробовать ещё раз'));
    await settle(tester);
    expect(state(tester).selectedFormId, isNull);
    expect(state(tester).selectedMarkId, isNull);
    expect(state(tester).question, same(question));
    expect(find.byKey(const ValueKey('connection-build-gap')), findsOneWidget);
    expect(find.byType(ExerciseChoiceTile), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final position in ['в начале', 'в середине', 'в конце']) {
    testWidgets('пропуск $position на узком экране', (tester) async {
      final questions = (await tester.runAsync(
        loadConnectionBuildDebugQuestions,
      ))!;
      final question = questions.firstWhere(
        (question) => question.position == position,
      );
      await mount(tester, questions: [question], size: const Size(320, 640));
      expect(find.text('1. Выберите форму $position'), findsOneWidget);
      final rects = question.formOptions
          .map((option) => tester.getRect(form(option.id)))
          .toList();
      expect(
        rects.every((rect) => rect.width >= 44 && rect.height >= 44),
        isTrue,
      );
      expect(rects[0].overlaps(rects[1]), isFalse);
      expect(rects[1].overlaps(rects[2]), isFalse);
      await choose(tester, form(question.expectedFormId));
      await choose(tester, mark(question.expectedMarkId));
      expect(state(tester).evaluation!.correct, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('появление плиток по очереди и отключение анимаций', (
    tester,
  ) async {
    await mount(tester, wait: false);
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final fades = find.descendant(
      of: find.byType(ExerciseChoiceTile),
      matching: find.byType(FadeTransition),
    );
    final opacities = tester
        .widgetList<FadeTransition>(fades)
        .map((fade) => fade.opacity.value)
        .toList();
    expect(opacities.first, greaterThan(opacities[1]));
    expect(opacities.last, 0);
    await settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());

    await mount(tester, animations: false);
    expect(fades, findsNothing);
    await choose(tester, form(state(tester).question.expectedFormId));
    expect(find.byType(ExerciseChoiceTile), findsNWidgets(6));
    expect(fades, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('закрытие до автозвука отменяет воспроизведение', (tester) async {
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
