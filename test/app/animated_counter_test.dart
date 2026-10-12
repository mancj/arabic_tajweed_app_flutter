// Счётчик должен продолжать незаконченный проход при быстром изменении цели,
// сохранять место под все разряды и крупный текст, а при уменьшенном движении
// показывать итог сразу. Диктор читает цель, а не каждое промежуточное число.
// Вибрация привязана к достигнутому целому, а не к кадрам: финал звучит один
// раз, скрытые и фоновые переходы не создают отложенную очередь откликов.
import 'package:arabic_tajweed_app/app/resources/ui_text_styles.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/animated_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tick = 'HapticFeedbackType.selectionClick';
  const heavy = 'HapticFeedbackType.heavyImpact';
  final feedback = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const gaimon = MethodChannel('gaimon');

  setUp(() async {
    feedback.clear();
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    messenger.setMockMethodCallHandler(gaimon, (call) async {
      if (call.method == 'canSupportsHaptic') return true;
      feedback.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        feedback.add(call.arguments as String);
      }
      return null;
    });
    await AppHaptics.init();
  });

  tearDown(() async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    messenger.setMockMethodCallHandler(gaimon, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await AppHaptics.init();
  });

  Future<void> mount(
    WidgetTester tester, {
    required int value,
    int? initialValue,
    Duration duration = const Duration(seconds: 1),
    Duration delay = Duration.zero,
    bool reducedMotion = false,
    double textScale = 1,
    TextStyle? style,
    bool enableHaptics = false,
    bool tickerEnabled = true,
    GlobalKey<NavigatorState>? navigatorKey,
  }) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: TickerMode(
          enabled: tickerEnabled,
          child: Center(
            child: AnimatedCounter(
              value: value,
              initialValue: initialValue,
              duration: duration,
              delay: delay,
              curve: Curves.linear,
              style: style,
              enableHaptics: enableHaptics,
            ),
          ),
        ),
      ),
    ),
  );

  Finder number(String value) => find.descendant(
    of: find.byType(AnimatedCounter),
    matching: find.text(value),
  );

  double offset(WidgetTester tester, String value) {
    final window = tester.getRect(find.byType(AnimatedCounter));
    return (tester.getCenter(number(value)).dy - window.center.dy) /
        window.height;
  }

  Future<void> begin(WidgetTester tester) async {
    // flutter_animate запускает проход после первого кадра; следующий кадр
    // задаёт нулевой момент, от которого считаются проверяемые интервалы.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('числа уходят вверх, следующие входят снизу за общий срок', (
    tester,
  ) async {
    await mount(
      tester,
      value: 7,
      initialValue: 0,
      delay: const Duration(milliseconds: 300),
      duration: const Duration(milliseconds: 700),
    );
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 250));
    expect(number('0'), findsOneWidget);
    expect(offset(tester, '0'), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(offset(tester, '0'), closeTo(-.5, .01));
    expect(offset(tester, '1'), closeTo(.5, .01));
    for (var day = 1; day < 7; day++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(number('$day'), findsOneWidget);
      expect(offset(tester, '$day'), lessThan(0));
      expect(offset(tester, '${day + 1}'), greaterThan(0));
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(number('7'), findsOneWidget);
    expect(offset(tester, '7'), 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('быстрая смена цели сохраняет дробное положение текущих цифр', (
    tester,
  ) async {
    await mount(tester, value: 10, initialValue: 0);
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 350));
    final before = offset(tester, '3');

    await mount(tester, value: 20, initialValue: 0);
    expect(offset(tester, '3'), closeTo(before, .001));
    expect(offset(tester, '4'), greaterThan(0));
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 150));
    final displayed = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AnimatedCounter),
            matching: find.byType(Text),
          ),
        )
        .map((text) => int.parse(text.data!))
        .toList();
    expect(displayed.every((value) => value > 3 && value < 20), isTrue);

    await mount(tester, value: -3);
    expect(number('20'), findsNothing);
    expect(number('0'), findsNothing);
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(offset(tester, '2'), lessThan(0));
    expect(offset(tester, '1'), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(number('-3'), findsOneWidget);
    expect(offset(tester, '-3'), 0);
  });

  testWidgets('обновление стиля и initialValue не запускает счёт заново', (
    tester,
  ) async {
    await mount(tester, value: 7, initialValue: 0);
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final before = offset(tester, '3');
    await mount(
      tester,
      value: 7,
      initialValue: -10,
      style: UITextStyles.semibold20.copyWith(color: Colors.blue),
    );
    expect(offset(tester, '3'), closeTo(before, .001));
    await tester.pump(const Duration(milliseconds: 500));
    expect(number('7'), findsOneWidget);
    expect(offset(tester, '7'), 0);
    await mount(tester, value: 7, initialValue: -20);
    expect(number('7'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'разряды и крупный текст помещаются без изменения окна в движении',
    (tester) async {
      await mount(tester, value: 9, textScale: 3);
      expect(number('9'), findsOneWidget);
      expect(offset(tester, '9'), 0);
      await mount(tester, value: 10, textScale: 3);
      final reserved = tester.getSize(find.byType(AnimatedCounter));
      await begin(tester);
      for (var step = 0; step < 4; step++) {
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.getSize(find.byType(AnimatedCounter)), reserved);
      }
      expect(
        tester.getSize(number('10')).width,
        lessThanOrEqualTo(reserved.width),
      );
      expect(
        tester.getSize(number('10')).height,
        lessThanOrEqualTo(reserved.height),
      );
      await mount(tester, value: 9, textScale: 3);
      expect(tester.getSize(find.byType(AnimatedCounter)), reserved);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedCounter)), reserved);

      await mount(tester, value: -12, textScale: 3);
      final signed = tester.getSize(find.byType(AnimatedCounter));
      await begin(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(find.byType(AnimatedCounter)), signed);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(number('-12')).width,
        lessThanOrEqualTo(signed.width),
      );
      expect(tester.getSize(find.byType(AnimatedCounter)), signed);
    },
  );

  testWidgets(
    'уменьшенное движение сразу завершает счёт и не возобновляет его',
    (tester) async {
      await mount(tester, value: 7, initialValue: 0);
      await begin(tester);
      await tester.pump(const Duration(milliseconds: 250));
      await mount(tester, value: 7, reducedMotion: true);
      expect(number('7'), findsOneWidget);
      expect(offset(tester, '7'), 0);
      await mount(tester, value: 10, reducedMotion: true);
      expect(number('10'), findsOneWidget);
      await mount(tester, value: 10);
      expect(number('10'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('диктор читает только цель до начала и во время счёта', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester, value: 7, initialValue: 0);
      expect(find.bySemanticsLabel('7'), findsOneWidget);
      expect(find.bySemanticsLabel('0'), findsNothing);
      await begin(tester);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.bySemanticsLabel('7'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^[0-6]$')), findsNothing);
      await mount(tester, value: 10);
      expect(find.bySemanticsLabel('10'), findsOneWidget);
      expect(find.bySemanticsLabel('7'), findsNothing);
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('вибрация выключена по умолчанию, начальное число молчит', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: AnimatedCounter(value: 7, initialValue: 0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(feedback, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, value: 7, enableHaptics: true);
    await tester.pumpAndSettle();
    expect(feedback, isEmpty);
  });

  testWidgets(
    'достигнутые числа дают тик, конечное один heavy без лишнего тика',
    (tester) async {
      await mount(
        tester,
        value: 7,
        initialValue: 0,
        enableHaptics: true,
        duration: const Duration(milliseconds: 700),
      );
      await begin(tester);
      expect(feedback, isEmpty);
      for (var day = 1; day <= 6; day++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(feedback, List.filled(day, tick));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(feedback, [...List.filled(6, tick), heavy]);
      await mount(
        tester,
        value: 7,
        initialValue: -100,
        enableHaptics: true,
        style: UITextStyles.semibold20.copyWith(color: Colors.blue),
      );
      await tester.pumpAndSettle();
      expect(feedback, [...List.filled(6, tick), heavy]);
    },
  );

  testWidgets('пропущенные кадры дают только один актуальный отклик', (
    tester,
  ) async {
    await mount(
      tester,
      value: 7,
      initialValue: 0,
      enableHaptics: true,
      duration: const Duration(milliseconds: 700),
    );
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(feedback, [tick]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback, [tick, heavy]);
    await tester.pumpAndSettle();
    expect(feedback, [tick, heavy]);
  });

  testWidgets('быстрая смена цели не даёт heavy на прежнем конечном числе', (
    tester,
  ) async {
    await mount(
      tester,
      value: 7,
      initialValue: 0,
      enableHaptics: true,
      duration: const Duration(milliseconds: 700),
    );
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback, [tick]);
    await mount(
      tester,
      value: 10,
      enableHaptics: true,
      duration: const Duration(milliseconds: 700),
    );
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 450));
    expect(feedback, [tick, tick]);
    await tester.pump(const Duration(milliseconds: 250));
    expect(feedback, [tick, tick, heavy]);
    await tester.pumpAndSettle();
    expect(feedback, [tick, tick, heavy]);
  });

  testWidgets(
    'отключённый TickerMode не выпускает отложенный финальный heavy',
    (tester) async {
      await mount(tester, value: 7, initialValue: 0, enableHaptics: true);
      await begin(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(feedback, [tick]);
      await mount(tester, value: 7, enableHaptics: true, tickerEnabled: false);
      await tester.pump(const Duration(seconds: 2));
      expect(feedback, [tick]);
      await mount(tester, value: 7, enableHaptics: true);
      await tester.pumpAndSettle();
      expect(feedback, [tick]);
      await mount(tester, value: 8, enableHaptics: true);
      await tester.pumpAndSettle();
      expect(feedback, [tick, heavy]);
    },
  );

  testWidgets('неактивное приложение не даёт вибрации после возвращения', (
    tester,
  ) async {
    await mount(tester, value: 7, initialValue: 0, enableHaptics: true);
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback, [tick]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(feedback, [tick]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(feedback, [tick]);
  });

  testWidgets('закрытая другим экраном страница не даёт поздний heavy', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await mount(
      tester,
      value: 7,
      initialValue: 0,
      enableHaptics: true,
      navigatorKey: navigator,
    );
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback, [tick]);
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, __, ___) => const SizedBox.expand(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(feedback, [tick]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(feedback, [tick]);
  });

  testWidgets(
    'мгновенные переходы дают heavy один раз, без промежуточных тиков',
    (tester) async {
      await mount(
        tester,
        value: 7,
        initialValue: 0,
        enableHaptics: true,
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      expect(feedback, [heavy]);
      await mount(
        tester,
        value: 7,
        initialValue: 2,
        enableHaptics: true,
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      expect(feedback, [heavy]);
      await mount(tester, value: 9, enableHaptics: true, reducedMotion: true);
      await tester.pumpAndSettle();
      expect(feedback, [heavy, heavy]);
      await mount(
        tester,
        value: 10,
        enableHaptics: true,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      expect(feedback, [heavy, heavy, heavy]);
    },
  );

  testWidgets('после закрытия счётчика откликов больше нет', (tester) async {
    await mount(tester, value: 7, initialValue: 0, enableHaptics: true);
    await begin(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback, [tick]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(feedback, [tick]);
  });
}
