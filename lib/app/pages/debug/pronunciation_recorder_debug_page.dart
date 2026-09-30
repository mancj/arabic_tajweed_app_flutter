import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/pronunciation_recorder_widget.dart';

/// Демонстрация состояний без доступа к микрофону и обращения к серверу.
class PronunciationRecorderDebugPage extends StatefulWidget {
  static const routeName = '/debug/pronunciation-recorder';

  const PronunciationRecorderDebugPage({super.key});

  @override
  State<PronunciationRecorderDebugPage> createState() =>
      _PronunciationRecorderDebugPageState();
}

class _PronunciationRecorderDebugPageState
    extends State<PronunciationRecorderDebugPage> {
  final ValueNotifier<double> _level = ValueNotifier(0);
  final math.Random _random = math.Random(17);
  PronunciationRecorderState _state = PronunciationRecorderState.idle;
  Timer? _levelTimer;
  Timer? _checkTimer;

  void _start() {
    _checkTimer?.cancel();
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 95), (_) {
      _level.value = .12 + _random.nextDouble() * .8;
    });
    setState(() => _state = PronunciationRecorderState.recording);
  }

  void _stop() {
    _levelTimer?.cancel();
    _level.value = 0;
    setState(() => _state = PronunciationRecorderState.checking);
    _checkTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _state = PronunciationRecorderState.idle);
    });
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _checkTimer?.cancel();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Виджет записи',
    builder: (context, insets) => SingleChildScrollView(
      padding: insets,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Margin.vertical(48),
              SizedBox(
                height: 300,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: PronunciationRecorderWidget(
                    state: _state,
                    level: _level,
                    onRecordPressed: _start,
                    onStopPressed: _stop,
                  ),
                ),
              ),
              const Margin.vertical(24),
              Text(
                'Демонстрация: звук имитируется, проверка длится 3 секунды.',
                textAlign: TextAlign.center,
                style: UITextStyles.monoRegular12.copyWith(
                  color: UIColors.secondary1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
