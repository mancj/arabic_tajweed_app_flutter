import 'dart:async';
import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../resources/ui_resources.dart';
import '../margin.dart';
import 'glow_wave_widget.dart';

enum PronunciationRecorderState { idle, recording, checking }

/// Внешний код управляет записью и проверкой; карточка показывает их состояние.
/// [level] — нормированная громкость микрофона от 0 до 1. Если её нет,
/// дорожка остаётся ровной: виджет не выдаёт придуманную волну за живой звук.
class PronunciationRecorderWidget extends StatefulWidget {
  const PronunciationRecorderWidget({
    required this.state,
    this.level,
    this.onRecordPressed,
    this.onStopPressed,
    super.key,
  });

  final PronunciationRecorderState state;
  final ValueListenable<double>? level;
  final VoidCallback? onRecordPressed;
  final VoidCallback? onStopPressed;

  @override
  State<PronunciationRecorderWidget> createState() =>
      _PronunciationRecorderWidgetState();
}

class _PronunciationRecorderWidgetState
    extends State<PronunciationRecorderWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  static const _sampleInterval = 120;
  static const _emptySample = _WaveSample(level: 0, enteredAt: -1000);
  final List<_WaveSample> _samples = List<_WaveSample>.filled(
    48,
    _emptySample,
    growable: true,
  );
  _WaveSample _outgoingSample = _emptySample;
  Timer? _timer;
  int _lastSampleAt = 0;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.state == PronunciationRecorderState.recording) _start();
  }

  @override
  void didUpdateWidget(PronunciationRecorderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;
    if (widget.state == PronunciationRecorderState.recording) {
      _start();
    } else {
      _timer?.cancel();
      _stopwatch.stop();
      if (widget.state == PronunciationRecorderState.idle) {
        _elapsed = Duration.zero;
        _samples.fillRange(0, _samples.length, _emptySample);
        _outgoingSample = _emptySample;
      }
    }
  }

  void _start() {
    _timer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    _elapsed = Duration.zero;
    _lastSampleAt = 0;
    _samples.fillRange(0, _samples.length, _emptySample);
    _outgoingSample = _emptySample;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = _stopwatch.elapsed;
        final now = _elapsed.inMilliseconds;
        if (now - _lastSampleAt >= _sampleInterval) {
          _lastSampleAt = now;
          _outgoingSample = _samples.removeAt(0);
          _samples.add(
            _WaveSample(
              level: (widget.level?.value ?? 0).clamp(0, 1).toDouble(),
              enteredAt: now,
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String get _time {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (_elapsed.inMilliseconds % 1000).toString().padLeft(
      3,
      '0',
    );
    return '$minutes:$seconds.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.state == PronunciationRecorderState.recording;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    MediaQuery.platformBrightnessOf(context);

    return Container(
      decoration: BoxDecoration(
        color: UIColors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: UIColors.borders),
        boxShadow: [
          BoxShadow(
            color: UIColors.shadows,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedCrossFade(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 360),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            sizeCurve: Curves.easeInOutCubic,
            alignment: Alignment.bottomCenter,
            crossFadeState: recording
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecordingWaveView(
                  samples: _samples,
                  outgoingSample: _outgoingSample,
                  elapsedMilliseconds: _elapsed.inMilliseconds,
                  lastSampleAt: _lastSampleAt,
                  sampleInterval: _sampleInterval,
                  animate: !reduceMotion,
                ),
                const Margin.vertical(16),
              ],
            ),
          ),
          Row(
            key: const ValueKey('recorder-controls'),
            children: [
              if (widget.state == PronunciationRecorderState.checking) ...[
                const _CheckingWaveView(),
                const Margin.horizontal(16),
              ],
              Expanded(
                child: switch (widget.state) {
                  PronunciationRecorderState.idle => const _IdleRecorderView(),
                  PronunciationRecorderState.recording =>
                    _RecordingRecorderView(time: _time),
                  PronunciationRecorderState.checking =>
                    const _CheckingRecorderView(),
                },
              ),
              if (widget.state != PronunciationRecorderState.checking) ...[
                const Margin.horizontal(16),
                _RecorderActionButton(
                  key: const ValueKey('recorder-action'),
                  recording: recording,
                  onRecordPressed: widget.onRecordPressed,
                  onStopPressed: widget.onStopPressed,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IdleRecorderView extends StatelessWidget {
  const _IdleRecorderView();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Запишите произношение', style: UITextStyles.monoSemibold14),
      const Margin.vertical(4),
      Text(
        'Нажмите кнопку записи',
        key: const ValueKey('recorder-status'),
        style: UITextStyles.monoRegular12.copyWith(color: UIColors.secondary1),
      ),
    ],
  ).animate().fadeIn();
}

class _RecordingRecorderView extends StatelessWidget {
  const _RecordingRecorderView({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          const _RecordingDot(),
          const Margin.horizontal(8),
          Flexible(
            child: Text('Идёт запись', style: UITextStyles.monoSemibold14),
          ),
        ],
      ),
      const Margin.vertical(0),
      Text(
        time,
        key: const ValueKey('recorder-status'),
        style: UITextStyles.monoRegular18.copyWith(color: UIColors.primary),
      ),
    ],
  );
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot();

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
      width: 6,
      height: 6,
    );
    if (MediaQuery.disableAnimationsOf(context)) return dot;
    return dot
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fadeIn(
          begin: .15,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
  }
}

class _CheckingRecorderView extends StatelessWidget {
  const _CheckingRecorderView();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Проверяем произношение', style: UITextStyles.monoSemibold14)
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1000.ms,
            delay: 200.ms,
            color: UIColors.backgroundShapes1,
          ),
      const Margin.vertical(4),
      Text(
        'Пожалуйста, подождите',
        key: const ValueKey('recorder-status'),
        style: UITextStyles.monoRegular12.copyWith(color: UIColors.secondary1),
      ),
    ],
  ).animate().fadeIn();
}

class _RecordingWaveView extends StatelessWidget {
  const _RecordingWaveView({
    required this.samples,
    required this.outgoingSample,
    required this.elapsedMilliseconds,
    required this.lastSampleAt,
    required this.sampleInterval,
    required this.animate,
  });

  final List<_WaveSample> samples;
  final _WaveSample outgoingSample;
  final int elapsedMilliseconds;
  final int lastSampleAt;
  final int sampleInterval;
  final bool animate;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: CustomPaint(
      key: const ValueKey('recording-waveform'),
      painter: _RecordingWavePainter(
        samples: samples,
        outgoingSample: outgoingSample,
        elapsedMilliseconds: elapsedMilliseconds,
        lastSampleAt: lastSampleAt,
        sampleInterval: sampleInterval,
        animate: animate,
        color: UIColors.primary,
        quietColor: UIColors.secondary1,
      ),
    ),
  );
}

class _CheckingWaveView extends StatelessWidget {
  const _CheckingWaveView();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    height: 56,
    child: Center(
      child: GlowWaveWidget(
        width: 100,
        height: 48,
        pairCount: 6,
        amplitude: 14,
        glowIntensity: .2,
        lineWidth: 1,
        color: UIColors.text,
      ),
    ),
  ).animate().fadeIn();
}

/// Остаётся тем же элементом при переходе к записи, чтобы получить отпускание.
class _RecorderActionButton extends StatefulWidget {
  const _RecorderActionButton({
    required this.recording,
    required this.onRecordPressed,
    required this.onStopPressed,
    super.key,
  });

  final bool recording;
  final VoidCallback? onRecordPressed;
  final VoidCallback? onStopPressed;

  @override
  State<_RecorderActionButton> createState() => _RecorderActionButtonState();
}

class _RecorderActionButtonState extends State<_RecorderActionButton> {
  static const _holdThreshold = Duration(milliseconds: 250);

  Timer? _holdTimer;
  int? _activePointer;
  bool _startedOnDown = false;
  bool _stopOnRelease = false;
  bool _skipTap = false;
  bool _activePressCanAct = false;

  void _pointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    final canAct = switch (widget.recording) {
      true => widget.onStopPressed != null,
      false => widget.onRecordPressed != null,
    };
    _activePressCanAct = canAct;
    if (canAct) AppHaptics.heavy();
    _startedOnDown = !widget.recording;
    _skipTap = _startedOnDown;
    _stopOnRelease = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdThreshold, () => _stopOnRelease = true);
    if (_startedOnDown) widget.onRecordPressed?.call();
  }

  void _pointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _holdTimer?.cancel();
    if (_activePressCanAct) AppHaptics.medium();
    _activePressCanAct = false;
    if (_stopOnRelease) {
      _skipTap = true;
      widget.onStopPressed?.call();
    }
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _holdTimer?.cancel();
    _activePressCanAct = false;
    _skipTap = false;
    if (_startedOnDown) widget.onStopPressed?.call();
  }

  void _tap() {
    if (_skipTap) {
      _skipTap = false;
      return;
    }
    if (widget.recording) {
      widget.onStopPressed?.call();
    } else {
      widget.onRecordPressed?.call();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (widget.recording) {
      true => ('Остановить запись', Icons.stop_rounded),
      false => ('Начать запись', Icons.mic_rounded),
    };
    return Semantics(
      button: true,
      label: label,
      child: Listener(
        onPointerDown: _pointerDown,
        onPointerUp: _pointerUp,
        onPointerCancel: _pointerCancel,
        child: CircleButton(
          onTap: _tap,
          hapticOnTap: false,
          borderColor: Colors.red[400]!,
          gradient: LinearGradient(
            colors: [Colors.red[700]!, Colors.red[700]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red[500]!.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          size: 52,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, size: 28, color: UIColors.primaryButtonText),
          ),
        ).animate().shimmer(duration: 500.ms, delay: 500.ms),
      ),
    );
  }
}

class _WaveSample {
  const _WaveSample({required this.level, required this.enteredAt});

  final double level;
  final int enteredAt;
}

class _RecordingWavePainter extends CustomPainter {
  const _RecordingWavePainter({
    required this.samples,
    required this.outgoingSample,
    required this.elapsedMilliseconds,
    required this.lastSampleAt,
    required this.sampleInterval,
    required this.animate,
    required this.color,
    required this.quietColor,
  });

  final List<_WaveSample> samples;
  final _WaveSample outgoingSample;
  final int elapsedMilliseconds;
  final int lastSampleAt;
  final int sampleInterval;
  final bool animate;
  final Color color;
  final Color quietColor;

  static const _growDuration = 240;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    final baseline = Paint()
      ..color = quietColor.withValues(alpha: .35)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset.zero.translate(0, center),
      Offset(size.width, center),
      baseline,
    );
    final step = size.width / samples.length;
    final travel = animate
        ? ((elapsedMilliseconds - lastSampleAt) / sampleInterval).clamp(
            0.0,
            1.0,
          )
        : 1.0;
    _drawSample(
      canvas,
      outgoingSample,
      step * -travel - 1,
      center,
      size,
      elapsedMilliseconds,
    );
    for (var index = 0; index < samples.length; index++) {
      _drawSample(
        canvas,
        samples[index],
        step * (index + 1 - travel) - 1,
        center,
        size,
        elapsedMilliseconds,
      );
    }
    final cursor = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width - 1, center - 16),
      Offset(size.width - 1, center + 16),
      cursor,
    );
  }

  void _drawSample(
    Canvas canvas,
    _WaveSample sample,
    double x,
    double center,
    Size size,
    int now,
  ) {
    if (x < 0 || x > size.width) return;
    final age = animate
        ? ((now - sample.enteredAt) / _growDuration).clamp(0.0, 1.0)
        : 1.0;
    final growth = Curves.easeOutCubic.transform(age);
    final height = 2 + math.min(1, sample.level) * (size.height - 12) * growth;
    final step = size.width / samples.length;
    final paint = Paint()
      ..color = UIColors.text
      ..strokeWidth = math.min(2.2, step * .46)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x, center - height / 2),
      Offset(x, center + height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RecordingWavePainter oldDelegate) => true;
}
