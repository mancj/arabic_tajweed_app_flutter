// Регрессионная проверка: запись должна раскрывать карточку и запускать часы,
// а проверка — остановить их и показать светящуюся волну слева.
// Удержание начинает запись сразу; при перестройке карточки отпускание нельзя терять.
// Полоса волн должна плавно закрываться, иначе она исчезает раньше карточки.
// Системный запрос может отменить жест: запись и ссылка на настройки остаются доступны.
// Обычная речь на −17 dBFS должна быть видимой, а комнатный фон — коротким:
// линейная амплитуда прячет голос, слишком чувствительная шкала раздувает фон.
// Частицы появляются только при записи и не перехватывают остановку кнопкой.
// Публичные настройки управляют рисунком, а нулевой лимит и отключение анимаций
// убирают частицы, чтобы эффект можно было отключить без изменения записи.
// Скорость меняет полёт уже летящих частиц и позволяет поставить его на паузу.
// Их исходный цвет совпадает с тёмной частью градиента кнопки.
import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/widgets/ui_kit/glow_wave_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/ring_sparks.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('частицы видны только при записи и не мешают остановке', (
    tester,
  ) async {
    final state = ValueNotifier(PronunciationRecorderState.idle);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: ValueListenableBuilder<PronunciationRecorderState>(
                valueListenable: state,
                builder: (context, value, _) => PronunciationRecorderWidget(
                  state: value,
                  onRecordPressed: () =>
                      state.value = PronunciationRecorderState.recording,
                  onStopPressed: () =>
                      state.value = PronunciationRecorderState.checking,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_particles(tester), isEmpty);

    final action = find.byKey(const ValueKey('recorder-action'));
    await tester.tap(action);
    await tester.pump();
    for (var frame = 0; frame < 100; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final particles = _particles(tester);
    expect(particles, isNotEmpty);
    final buttonGradient =
        tester.widget<CircleButton>(find.byType(CircleButton)).gradient!
            as LinearGradient;
    expect(
      particles.map((particle) => particle.color.toARGB32() & 0x00ffffff),
      everyElement(buttonGradient.colors.last.toARGB32() & 0x00ffffff),
    );

    await tester.tap(action);
    await tester.pump();
    expect(state.value, PronunciationRecorderState.checking);
    expect(_particles(tester), isEmpty);
    state.value = PronunciationRecorderState.idle;
    await tester.pumpAndSettle();
    expect(_particles(tester), isEmpty);
  });

  testWidgets('настройки частиц применяются во время записи', (tester) async {
    Future<void> pumpRecorder({
      double emissionRate = 24,
      int maxCount = 6,
      double speed = 1,
      bool reducedMotion = false,
    }) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: PronunciationRecorderWidget(
                  state: PronunciationRecorderState.recording,
                  particleMinRadius: 3,
                  particleMaxRadius: 4,
                  particleEmissionRate: emissionRate,
                  particleMaxCount: maxCount,
                  particleSpeed: speed,
                  particleColor: Colors.pink,
                  particleSeed: 71,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> fly(int frames) async {
      for (var frame = 0; frame < frames; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await pumpRecorder();
    await fly(100);
    final particles = _particles(tester);
    expect(particles, isNotEmpty);
    expect(particles.length, lessThanOrEqualTo(6));
    expect(
      particles.map((particle) => particle.radius),
      everyElement(inInclusiveRange(3, 4)),
    );
    expect(
      particles.map((particle) => particle.color.toARGB32() & 0x00ffffff),
      everyElement(Colors.pink.toARGB32() & 0x00ffffff),
    );

    await pumpRecorder(speed: 0);
    final pausedParticles = _particles(tester);
    await fly(100);
    expect(_particles(tester), pausedParticles);
    await pumpRecorder(emissionRate: 0, speed: 2);
    await fly(100);
    expect(_particles(tester), isEmpty);
    await pumpRecorder();
    await fly(100);
    expect(_particles(tester), isNotEmpty);
    await pumpRecorder(maxCount: 0);
    await fly(20);
    expect(_particles(tester), isEmpty);
    await pumpRecorder(reducedMotion: true);
    await fly(100);
    expect(_particles(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('волна показывает речь и оставляет комнатный фон коротким', (
    tester,
  ) async {
    for (final (peak, minHeight, maxHeight) in [
      (0.0, 2.0, 2.01),
      (.001, 2.0, 2.01), // −60 dBFS: слабый фон.
      (.01, 2.0, 2.01), // −40 dBFS: порог отображения.
      (math.pow(10, -35 / 20).toDouble(), 2.0, 5.0),
      (math.pow(10, -30 / 20).toDouble(), 2.0, 5.0),
      (math.pow(10, -17 / 20).toDouble(), 12.0, 24.0),
      (1.0, 12.0, 24.0),
    ]) {
      final level = ValueNotifier(peak);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SizedBox(
                width: 340,
                child: PronunciationRecorderWidget(
                  key: UniqueKey(),
                  state: PronunciationRecorderState.recording,
                  level: level,
                ),
              ),
            ),
          ),
        ),
      );
      // Таймер виджета считывает настоящий Stopwatch, а не часы pump.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 160));

      final wave = find.byKey(const ValueKey('recording-waveform'));
      final size = tester.getSize(wave);
      final canvas = TestRecordingCanvas();
      tester.widget<CustomPaint>(wave).painter!.paint(canvas, size);
      // Первая линия — основа дорожки, последняя — вертикальный курсор.
      final bars = canvas.invocations
          .where((call) => call.invocation.memberName == #drawLine)
          .toList();
      final heights = bars.skip(1).take(bars.length - 2).map((call) {
        final points = call.invocation.positionalArguments;
        return ((points[1] as Offset).dy - (points[0] as Offset).dy).abs();
      }).toList();
      expect(heights, isNotEmpty);
      expect(heights, everyElement(inInclusiveRange(2, size.height)));
      expect(heights, everyElement(lessThanOrEqualTo(maxHeight)));
      expect(heights, contains(greaterThanOrEqualTo(minHeight)));
      await tester.pumpWidget(const SizedBox.shrink());
      level.dispose();
    }
  });

  testWidgets('запись, таймер и проверка переключаются по нажатию', (
    tester,
  ) async {
    final state = ValueNotifier(PronunciationRecorderState.idle);
    final level = ValueNotifier(.5);
    addTearDown(state.dispose);
    addTearDown(level.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: ValueListenableBuilder<PronunciationRecorderState>(
                valueListenable: state,
                builder: (context, value, _) => PronunciationRecorderWidget(
                  state: value,
                  level: level,
                  onRecordPressed: () =>
                      state.value = PronunciationRecorderState.recording,
                  onStopPressed: () =>
                      state.value = PronunciationRecorderState.checking,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final idleHeight = tester
        .getSize(find.byType(PronunciationRecorderWidget))
        .height;
    await tester.tap(find.byKey(const ValueKey('recorder-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('recording-waveform')), findsOneWidget);
    expect(
      tester.getSize(find.byType(PronunciationRecorderWidget)).height,
      greaterThan(idleHeight),
    );
    expect(find.textContaining(RegExp(r'\d{2}:\d{2}\.\d{3}')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recorder-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final closingHeight = tester
        .getSize(find.byType(PronunciationRecorderWidget))
        .height;
    await tester.pump(const Duration(milliseconds: 400));
    final checkingHeight = tester
        .getSize(find.byType(PronunciationRecorderWidget))
        .height;
    expect(closingHeight, greaterThan(checkingHeight));
    expect(find.byType(GlowWaveWidget), findsOneWidget);
    expect(find.byKey(const ValueKey('recorder-action')), findsNothing);
    expect(find.text('Проверяем произношение'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(GlowWaveWidget)).dx,
      lessThan(tester.getTopLeft(find.text('Проверяем произношение')).dx),
    );
  });

  testWidgets('удержание записывает только до отпускания', (tester) async {
    final state = ValueNotifier(PronunciationRecorderState.idle);
    addTearDown(state.dispose);
    var starts = 0;
    var stops = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ValueListenableBuilder<PronunciationRecorderState>(
              valueListenable: state,
              builder: (context, value, _) => PronunciationRecorderWidget(
                state: value,
                onRecordPressed: () {
                  starts++;
                  state.value = PronunciationRecorderState.recording;
                },
                onStopPressed: () {
                  stops++;
                  state.value = PronunciationRecorderState.checking;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('recorder-action'))),
    );
    await tester.pump();
    expect(state.value, PronunciationRecorderState.recording);
    expect(starts, 1);
    expect(stops, 0);

    await tester.pump(const Duration(milliseconds: 600));
    expect(state.value, PronunciationRecorderState.recording);
    expect(starts, 1);
    expect(stops, 0);

    await gesture.up();
    await tester.pump();
    expect(state.value, PronunciationRecorderState.checking);
    expect(stops, 1);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('обычный тап оставляет запись до следующего нажатия', (
    tester,
  ) async {
    final state = ValueNotifier(PronunciationRecorderState.idle);
    addTearDown(state.dispose);
    var starts = 0;
    var stops = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<PronunciationRecorderState>(
            valueListenable: state,
            builder: (context, value, _) => PronunciationRecorderWidget(
              state: value,
              onRecordPressed: () {
                starts++;
                state.value = PronunciationRecorderState.recording;
              },
              onStopPressed: () {
                stops++;
                state.value = PronunciationRecorderState.checking;
              },
            ),
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('recorder-action'));
    final press = await tester.startGesture(tester.getCenter(action));
    await tester.pump();
    expect(starts, 1);
    await tester.pump(const Duration(milliseconds: 350));
    await press.up();
    await tester.pump();
    expect(state.value, PronunciationRecorderState.recording);
    expect(stops, 0);

    await tester.tap(action);
    await tester.pump();
    expect(state.value, PronunciationRecorderState.checking);
    expect(starts, 1);
    expect(stops, 1);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('системная отмена первого касания не останавливает запись', (
    tester,
  ) async {
    var starts = 0;
    var stops = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PronunciationRecorderWidget(
            state: PronunciationRecorderState.idle,
            onRecordPressed: () => starts++,
            onStopPressed: () => stops++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('recorder-action'))),
    );
    await tester.pump();
    expect(starts, 1);
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 600));
    expect(stops, 0);
  });

  testWidgets('после постоянного запрета открываются настройки', (
    tester,
  ) async {
    var settingsOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PronunciationRecorderWidget(
            state: PronunciationRecorderState.idle,
            microphonePermissionDenied: true,
            microphoneSettingsRequired: true,
            onOpenSettings: () => settingsOpened++,
          ),
        ),
      ),
    );

    expect(find.text('Нет доступа к микрофону'), findsOneWidget);
    expect(find.textContaining('Включите его в настройках'), findsOneWidget);
    await tester.tap(find.text('Открыть настройки'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(settingsOpened, 1);
  });

  // Оба способа начать запись должны давать сильный отклик при касании и
  // отдельный при отпускании, без лишнего лёгкого тика общей кнопки.
  testWidgets('тап и удержание дают отклик при касании и отпускании', (
    tester,
  ) async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const gaimonChannel = MethodChannel('gaimon');
    messenger.setMockMethodCallHandler(gaimonChannel, (call) async {
      if (call.method == 'canSupportsHaptic') return true;
      calls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(gaimonChannel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      await AppHaptics.init();
    });
    await AppHaptics.init();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PronunciationRecorderWidget(
            state: PronunciationRecorderState.idle,
            onRecordPressed: () {},
          ),
        ),
      ),
    );
    final action = find.byKey(const ValueKey('recorder-action'));

    await tester.tap(action);
    await tester.pump();
    expect(calls, [
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.mediumImpact',
    ]);

    calls.clear();
    final hold = await tester.startGesture(tester.getCenter(action));
    await tester.pump();
    expect(calls, ['HapticFeedbackType.heavyImpact']);
    await tester.pump(const Duration(milliseconds: 600));
    await hold.up();
    await tester.pump();
    expect(calls, [
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
    await tester.pump(const Duration(milliseconds: 120));
  });
}

List<({Offset point, double radius, Color color})> _particles(
  WidgetTester tester,
) {
  final paint = find.descendant(
    of: find.byType(RingSparks),
    matching: find.byType(CustomPaint),
  );
  if (paint.evaluate().isEmpty) return const [];
  final canvas = TestRecordingCanvas();
  tester
      .widget<CustomPaint>(paint)
      .painter!
      .paint(canvas, tester.getSize(paint));
  return canvas.invocations
      .where((call) => call.invocation.memberName == #drawCircle)
      .map((call) {
        final arguments = call.invocation.positionalArguments;
        return (
          point: arguments[0] as Offset,
          radius: arguments[1] as double,
          color: (arguments[2] as Paint).color,
        );
      })
      .toList();
}
