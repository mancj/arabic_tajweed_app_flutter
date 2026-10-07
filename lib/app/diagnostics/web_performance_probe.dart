import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../resources/ui_resources.dart';
import '../widgets/app_gesture_detector.dart';
import '../widgets/margin.dart';
import '../widgets/ui_kit/mono_text_button.dart';

/// Временный замер на реальном iPhone. Включается только отдельной
/// веб-сборкой WEB_PERF_PROBE; удалить после получения результатов сравнения.
class WebPerformanceProbe extends StatefulWidget {
  const WebPerformanceProbe({required this.child, super.key});

  final Widget child;

  @override
  State<WebPerformanceProbe> createState() => _WebPerformanceProbeState();
}

class _WebPerformanceProbeState extends State<WebPerformanceProbe> {
  final _frames = <FrameTiming>[];
  Timer? _timer;
  int? _startFrame;
  int? _endFrame;
  bool _busy = false;
  String? _report;
  late final bool _withoutMotion;

  @override
  void initState() {
    super.initState();
    _withoutMotion = Uri.base.queryParameters['press_motion'] == 'off';
    AppGestureDetector.animatePress = !_withoutMotion;
    SchedulerBinding.instance.addTimingsCallback(_collect);
  }

  void _collect(List<FrameTiming> timings) {
    final start = _startFrame;
    if (start == null) return;
    _frames.addAll(
      timings.where(
        (frame) =>
            frame.frameNumber > start &&
            (_endFrame == null || frame.frameNumber <= _endFrame!),
      ),
    );
  }

  void _start() {
    _frames.clear();
    _startFrame =
        SchedulerBinding.instance.platformDispatcher.frameData.frameNumber;
    _endFrame = null;
    setState(() {
      _busy = true;
      _report = null;
    });
    _timer = Timer(const Duration(seconds: 20), _finish);
  }

  void _finish() {
    _endFrame =
        SchedulerBinding.instance.platformDispatcher.frameData.frameNumber;
    // Отчёты приходят пачками. Последний кадр выводит накопленные данные,
    // но сам исключается из замера по номеру кадра.
    SchedulerBinding.instance.scheduleFrame();
    _timer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final count = _frames.length;
      final slow = _frames
          .where((frame) => frame.totalSpan.inMicroseconds > 16667)
          .length;
      final report = count == 0
          ? 'Кадры не получены — повторите замер с прокруткой.'
          : '${_withoutMotion ? "B" : "A"}: $count кадров; '
                'p95 подготовка ${_p95((f) => f.buildDuration)} мс; '
                'рисование ${_p95((f) => f.rasterDuration)} мс; '
                'весь кадр ${_p95((f) => f.totalSpan)} мс; '
                '>16,7 мс ${(slow * 100 / count).round()}%';
      _startFrame = null;
      setState(() {
        _busy = false;
        _report = report;
      });
    });
  }

  String _p95(Duration Function(FrameTiming) metric) {
    final values = _frames.map((frame) => metric(frame).inMicroseconds).toList()
      ..sort();
    return (values[(values.length * .95).ceil() - 1] / 1000).toStringAsFixed(1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    AppGestureDetector.animatePress = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: widget.child),
      ColoredBox(
        color: UIColors.cardBackground,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _withoutMotion
                      ? 'B · Без уменьшения при нажатии'
                      : 'A · Обычные нажатия',
                  style: UITextStyles.semibold14,
                ),
                const Margin.vertical(4),
                if (_report case final report?)
                  SelectableText(report, style: UITextStyles.regular12)
                else
                  Text(
                    _busy
                        ? '20 секунд: листайте и открывайте экраны…'
                        : 'Откройте «Мой путь», затем начните замер.',
                    style: UITextStyles.regular12,
                  ),
                MonoTextButton(
                  title: _busy ? 'Идёт замер…' : 'Измерить 20 секунд',
                  onPressed: _busy ? null : _start,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
