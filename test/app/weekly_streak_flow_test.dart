// Недельное поздравление открывается автоматически после занятия на седьмой
// день, в том числе когда серия началась в середине недели. Непоказанный экран
// не расходует достижение; показ сохраняется между запусками,
// а закрытие поздравления возвращает к экрану, с которого началось занятие.
// Удар эмблемы и остановка фона не запускают счётчик заново.
// На странице вибрацию ведёт счётчик: тики при смене чисел и один тяжёлый
// отклик в конце. Закрытое поздравление больше не вибрирует.
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/pages/streak/weekly_streak_page.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/animated_counter.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/plugin_mocks.dart';
import '../helpers/text_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime(2026, 10, 14, 12);
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  late ProgressDatabase database;
  late SharedPreferences preferences;

  setUp(() async {
    mockPlatformPlugins();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    Get.put(SharedPreferenceManager(preferences), permanent: true);
    database = ProgressDatabase(NativeDatabase.memory());
    for (var day = 8; day <= 13; day++) {
      await database.finishSession(
        sessionId: day - 7,
        at: DateTime(2026, 10, day, 12),
        purpose: LessonPurpose.standard,
        exerciseCount: 8,
        firstTryCorrect: 8,
      );
    }
  });

  tearDown(() async {
    Get.reset();
    await database.close();
  });

  Future<LessonController> start() async {
    final controller = Get.put(
      LessonController(
        database: database,
        curriculum: curriculum,
        explanationBundle: TextAssetBundle.forCurriculum(curriculum),
        topicId: 'm.first',
        rules: const LearningRules(requirePronunciation: false),
        clock: AppClock(systemNow: () => today),
        audio: _SilentAudio(),
        shapeLoader: (asset) async {
          final path = asset.contains('/')
              ? 'assets/svg/$asset.svg'
              : 'assets/svg/alphabet/$asset.svg';
          return TracingShapeSvg.parse(
            File(path).readAsStringSync(),
            id: asset,
          );
        },
      ),
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      if (controller.stage.value != LessonStage.loading) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(controller.loadError.value, isNull);
    expect(controller.stage.value, isNot(LessonStage.loading));
    return controller;
  }

  Future<void> finish(LessonController controller) async {
    while (controller.stage.value == LessonStage.intro) {
      await controller.nextIntro();
    }
    await controller.finishLessonCorrectly();
    expect(controller.stage.value, LessonStage.finished);
  }

  Future<List<String>> recordHaptics() async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('gaimon');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'canSupportsHaptic') return true;
      calls.add(call.method);
      return null;
    });
    // Gaimon направляет selection и iOS heavy через канал Flutter;
    // success и Android heavy идут через собственный канал плагина.
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(switch (call.arguments) {
          'HapticFeedbackType.selectionClick' => 'selection',
          'HapticFeedbackType.heavyImpact' => 'heavy',
          _ => call.arguments.toString(),
        });
      }
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      await AppHaptics.init();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await AppHaptics.init();
    return calls;
  }

  test('оставленный итог сохраняет достижение, показ не повторяется', () async {
    var controller = await start();
    expect(controller.weeklyStreak.value, isNull);
    await finish(controller);
    expect(controller.weeklyStreak.value?.days, 7);
    expect(
      SharedPreferenceManager(preferences).weeklyStreakCelebratedStart.get(),
      isNull,
    );
    Get.delete<LessonController>();

    controller = await start();
    await finish(controller);
    expect(controller.weeklyStreak.value?.days, 7);
    await controller.markWeeklyStreakPresented();
    Get.delete<LessonController>();
    Get.delete<SharedPreferenceManager>(force: true);
    Get.put(SharedPreferenceManager(preferences), permanent: true);

    controller = await start();
    await finish(controller);
    expect(controller.weeklyStreak.value, isNull);
  });

  for (final closeWithBack in [false, true]) {
    testWidgets('достижение возвращает на главную: назад=$closeWithBack', (
      tester,
    ) async {
      final controller = await tester.runAsync(start);
      await tester.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(body: Text('Главная')),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      );
      Get.to<void>(() => const LessonPage(), routeName: LessonPage.routeName);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyStreakPage), findsNothing);
      expect(
        SharedPreferenceManager(preferences).weeklyStreakCelebratedStart.get(),
        isNull,
      );

      await tester.runAsync(() => finish(controller!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WeeklyStreakPage), findsOneWidget);
      expect(
        SharedPreferenceManager(preferences).weeklyStreakCelebratedStart.get(),
        DateTime(2026, 10, 8),
      );
      if (closeWithBack) {
        Get.back<void>();
      } else {
        final repeatAction = tester
            .widget<Semantics>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == 'Продолжить путь',
              ),
            )
            .properties
            .onTap;
        await tester.tap(find.text('Продолжить путь'));
        repeatAction?.call();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(LessonPage), findsNothing);
      expect(find.text('Главная'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('после пропуска дня поздравление не заменяет итог занятия', (
    tester,
  ) async {
    await database.clear();
    for (final day in [7, 8, 9, 11, 12, 13]) {
      await database.finishSession(
        sessionId: day,
        at: DateTime(2026, 10, day, 12),
        purpose: LessonPurpose.standard,
        exerciseCount: 8,
        firstTryCorrect: 8,
      );
    }
    final controller = await tester.runAsync(start);
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('Главная')),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    Get.to<void>(() => const LessonPage(), routeName: LessonPage.routeName);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => finish(controller!));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(WeeklyStreakPage), findsNothing);
    expect(find.text('Закрыть'), findsOneWidget);
    expect(controller!.weeklyStreak.value, isNull);
    expect(
      SharedPreferenceManager(preferences).weeklyStreakCelebratedStart.get(),
      isNull,
    );
    await tester.tap(find.text('Закрыть'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Главная'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('календарь поздравления показывает семь дней достигнутой серии', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyStreakPage(achievedOn: DateTime(2027, 1, 6)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label)
        .whereType<String>()
        .where((label) => label.endsWith(': занятие выполнено'));
    expect(labels, [
      '31.12.2026: занятие выполнено',
      for (var day = 1; day <= 6; day++) '$day.1.2027: занятие выполнено',
    ]);
    expect(
      tester.getCenter(find.text('Чт')).dx,
      lessThan(tester.getCenter(find.text('Ср')).dx),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('предпросмотр не расходует настоящее достижение', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('Отладка')),
        getPages: [
          GetPage(
            name: WeeklyStreakPage.routeName,
            page: () => const WeeklyStreakPage(),
          ),
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    Get.toNamed<void>(WeeklyStreakPage.routeName);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WeeklyStreakPage), findsOneWidget);
    await tester.tap(find.text('Продолжить путь'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Отладка'), findsOneWidget);
    expect(
      SharedPreferenceManager(preferences).weeklyStreakCelebratedStart.get(),
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('счётчик и вибрация не повторяются при ударе и остановке фона', (
    tester,
  ) async {
    final haptics = await recordHaptics();
    await tester.pumpWidget(const MaterialApp(home: WeeklyStreakPage()));
    await tester.pump();
    final counter = find.byType(AnimatedCounter);
    final state = tester.state<State>(counter);
    var sawImpact = false;

    for (var frame = 0; frame < 45; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.state<State>(counter), same(state));
      final impact = find.ancestor(
        of: counter,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              widget.transform.getMaxScaleOnAxis() > 1.001,
        ),
      );
      if (impact.evaluate().isEmpty) continue;
      sawImpact = true;
    }

    expect(sawImpact, isTrue);
    final seven = find.descendant(of: counter, matching: find.text('7'));
    expect(seven, findsOneWidget);
    expect(
      (tester.getCenter(seven) - tester.getCenter(counter)).dy.abs(),
      lessThan(1),
    );
    expect(haptics.where((method) => method == 'selection'), isNotEmpty);
    expect(haptics.where((method) => method == 'heavy'), hasLength(1));
    expect(haptics, isNot(contains('success')));
    expect(haptics.last, 'heavy');
    final completedHaptics = List<String>.of(haptics);
    await tester.pump(const Duration(seconds: 1));
    expect(haptics, orderedEquals(completedHaptics));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('выход до семёрки отменяет поздний тяжёлый отклик', (
    tester,
  ) async {
    final haptics = await recordHaptics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Главная'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const WeeklyStreakPage()),
    );
    await tester.pump();
    for (
      var frame = 0;
      frame < 100 && !haptics.contains('selection');
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(haptics, contains('selection'));
    expect(haptics, isNot(contains('heavy')));
    await tester.tap(find.text('Продолжить путь'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(WeeklyStreakPage), findsNothing);
    expect(find.text('Главная'), findsOneWidget);
    final hapticsAfterExit = List<String>.of(haptics);
    await tester.pump(const Duration(seconds: 5));
    expect(haptics, orderedEquals(hapticsAfterExit));
    expect(haptics, isNot(contains('heavy')));
    expect(haptics, isNot(contains('success')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _SilentAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  @override
  Future<void> dispose() async => track.dispose();

  @override
  Future<void> playAsset(String? asset) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> toggleAsset(String? asset) async {}
}
