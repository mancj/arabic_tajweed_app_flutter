import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'drawing_painter.dart';
import 'drawing_stroke.dart';
import 'tracing_shape.dart';

/// Слияние: откуда штрихи едут, куда приезжают и чем заливается часть.
class MergeState {
  final List<DrawingStroke> sources;
  final List<DrawingStroke> targets;
  final ResolvedTracingPart part;

  /// Сколько всего штрихов нарисовано к моменту слияния.
  final int strokeCount;

  final Color inkColor;

  const MergeState({
    required this.sources,
    required this.targets,
    required this.part,
    required this.strokeCount,
    required this.inkColor,
  });
}

/// Анимация слияния засчитанных штрихов с частью фигуры: штрихи едут на
/// линии буквы, во второй половине проявляется сама часть — она дорисовывает
/// то, чего человек чуть-чуть не дотянул, без рывка в конце.
///
/// Это картинка после зачёта, а не проверка. Холст запускает её, при новом
/// штрихе доводит до конца или отменяет, а в отрисовке отдаёт ей кисть.
/// Слушатели дёргаются на каждом кадре и при смене состояния.
class MergeAnimation extends ChangeNotifier {
  MergeAnimation({required TickerProvider vsync, required Duration duration})
    : _controller = AnimationController(vsync: vsync, duration: duration) {
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;
  late final Animation<double> _progress;

  MergeState? _state;
  ValueChanged<MergeState>? _onComplete;

  MergeState? get state => _state;
  bool get isActive => _state != null;

  set duration(Duration value) => _controller.duration = value;

  /// Запускает слияние. [onComplete] вызывается, когда анимация доиграла
  /// сама или её довели до конца [finalize]; при [cancel] — нет.
  void start(MergeState state, {required ValueChanged<MergeState> onComplete}) {
    _state = state;
    _onComplete = onComplete;
    notifyListeners();
    _controller
      ..reset()
      ..forward().then((_) {
        if (_state == state) _finish();
      });
  }

  /// Мгновенно доводит слияние до конца: часть засчитана, терять её нельзя,
  /// а доигрывать под новым штрихом нечего.
  void finalize() {
    if (!isActive) return;
    _controller.stop();
    _controller.value = 1;
    _finish();
  }

  void cancel() {
    if (!isActive) return;
    _controller.stop();
    _controller.value = 0;
    _state = null;
    notifyListeners();
  }

  void _finish() {
    final state = _state!;
    _state = null;
    notifyListeners();
    _onComplete?.call(state);
  }

  /// Рисует штрихи текущей части: без слияния — как есть, начиная со
  /// [skipStrokes] (те, что раньше, уже влиты в собранные части); во время
  /// слияния — на пути к линиям буквы, следом проявляя саму часть.
  void paint(
    Canvas canvas,
    Size size, {
    required List<DrawingStroke> strokes,
    required int skipStrokes,
    double? penWidth,
  }) {
    final state = _state;
    if (state == null) {
      DrawingPainter(
        strokes: skipStrokes == 0 ? strokes : strokes.sublist(skipStrokes),
      ).paint(canvas, size);
      return;
    }

    final t = _progress.value;
    DrawingPainter(
      strokes: [
        for (
          var i = 0;
          i < state.targets.length && i < state.sources.length;
          i++
        )
          DrawingStroke.lerp(state.sources[i], state.targets[i], t),
      ],
    ).paint(canvas, size);

    final fill = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    if (fill > 0) {
      state.part.paint(
        canvas,
        state.inkColor.withValues(alpha: fill),
        strokeWidth: penWidth,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
