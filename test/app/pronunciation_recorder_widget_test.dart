// Регрессионная проверка: запись должна раскрывать карточку и запускать часы,
// а проверка — остановить их и показать светящуюся волну слева.
// Удержание начинает запись сразу; при перестройке карточки отпускание нельзя терять.
// Полоса волн должна плавно закрываться, иначе она исчезает раньше карточки.
import 'package:arabic_tajweed_app/app/widgets/ui_kit/glow_wave_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    final recordingHeight = tester
        .getSize(find.byType(PronunciationRecorderWidget))
        .height;

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
    expect(closingHeight, lessThan(recordingHeight));
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
