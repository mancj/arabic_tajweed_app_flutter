import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'drawing_controller.dart';
import 'drawing_painter.dart';
import 'drawing_stroke.dart';
import 'tracing_matcher.dart';
import 'tracing_shape.dart';

export 'drawing_controller.dart';
export 'drawing_stroke.dart';
export 'tracing_matcher.dart';
export 'tracing_shape.dart';

/// Как холст работает с фигурой.
enum TracingMode {
  /// Фигура показана бледным контуром: пользователь обводит её и жмёт
  /// «Проверить» — сверяется вся буква целиком.
  tracing,

  /// Фигура скрыта: пользователь рисует по памяти, а части проверяются по
  /// очереди сразу после каждого штриха. Угаданная часть тут же заливается.
  freehand,
}

/// Холст, на котором пользователь рисует пальцем.
/// Линия сглаживается фильтром + сплайном, концы и стыки — круглые.
class DrawingCanvas extends StatefulWidget {
  final DrawingController? controller;

  /// Если задан, перекрывает цвет контроллера.
  final Color? color;

  /// Толщина пера в пикселях. Если не задана, перо берётся из фигуры
  /// ([TracingShape.strokeWidth], отмасштабированная под холст) — тогда
  /// нарисованная линия и залитая буква совпадают по толщине.
  final double? strokeWidth;

  final Color backgroundColor;

  /// Что делает холст с фигурой: показывает для обводки или прячет и
  /// принимает части по очереди.
  final TracingMode mode;

  /// Фигура-подсказка под штрихами: её пользователь обводит.
  final TracingShape? placeholder;
  final Color placeholderColor;
  final double placeholderPadding;

  /// Правила, по которым ввод признаётся совпавшим с фигурой.
  final TracingMatcher matcher;

  /// Длительность анимации слияния штрихов с фигурой.
  final Duration mergeDuration;

  /// В [TracingMode.freehand] убирать штрих, который не приблизил текущую
  /// часть к готовности. Иначе промах остаётся на холсте и портит точность
  /// всех следующих попыток. Работает начиная со второй части, когда буква
  /// уже стоит на своём месте и промах определяется однозначно.
  final bool discardMisses;

  final bool enabled;
  final VoidCallback? onStrokeStart;
  final ValueChanged<DrawingStroke>? onStrokeEnd;

  /// Результат каждой проверки [DrawingController.check].
  final ValueChanged<TracingMatchResult>? onChecked;

  /// Часть фигуры собрана: штрихи слились с ней и она залита.
  final ValueChanged<ResolvedTracingPart>? onPartCompleted;

  /// Прогресс изменился — например, для подсказки «шаг 1 из 2».
  final ValueChanged<TracingProgress>? onProgress;

  /// Вся фигура собрана.
  final VoidCallback? onMerged;

  const DrawingCanvas({
    Key? key,
    this.controller,
    this.color,
    this.strokeWidth,
    this.backgroundColor = Colors.transparent,
    this.mode = TracingMode.tracing,
    this.placeholder,
    this.placeholderColor = const Color(0x1F000000),
    this.placeholderPadding = 24,
    this.matcher = const TracingMatcher(),
    this.mergeDuration = const Duration(milliseconds: 450),
    this.discardMisses = true,
    this.enabled = true,
    this.onStrokeStart,
    this.onStrokeEnd,
    this.onChecked,
    this.onPartCompleted,
    this.onProgress,
    this.onMerged,
  }) : super(key: key);

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas>
    with SingleTickerProviderStateMixin {
  late DrawingController _controller;
  DrawingController? _internalController;

  late final AnimationController _mergeController = AnimationController(
    vsync: this,
    duration: widget.mergeDuration,
  );
  late final Animation<double> _mergeProgress = CurvedAnimation(
    parent: _mergeController,
    curve: Curves.easeInOutCubic,
  );

  /// Отдельный сигнал для нижнего слоя: завершённые штрихи перерисовываются
  /// только когда их список реально изменился, а не на каждое движение пальца.
  final _finishedRepaint = ValueNotifier<int>(0);

  _MergeState? _merge;

  /// Уже собранные части и число штрихов, потраченных на каждую: по этому
  /// счётчику откатывается прогресс при отмене.
  final List<_FilledPart> _filled = [];

  ResolvedTracingShape? _resolvedShape;
  Size? _resolvedFor;

  /// Буква, закреплённая там, где её нарисовал пользователь. Появляется,
  /// когда собрана первая часть: дальше остальные части сверяются
  /// относительно неё, а не относительно центра холста.
  ResolvedTracingShape? _anchored;

  /// Единственная толщина пера: ею рисует пользователь, ею же заливаются
  /// собранные части и рисуется подсказка.
  double? _penWidth;
  int? _activePointer;

  /// Лучшее покрытие текущей части: по нему видно, помог ли новый штрих.
  double _bestCoverage = 0;

  /// Штрихи до этого индекса уже влиты в собранные части и отдельно
  /// не рисуются.
  int get _consumedStrokes => _filled.isEmpty ? 0 : _filled.last.strokeCount;

  int get _partCount => widget.placeholder?.parts.length ?? 0;

  /// Фигура, с которой сейчас сверяемся: закреплённая, если она уже есть.
  ResolvedTracingShape? get _activeShape => _anchored ?? _resolvedShape;

  /// Габариты уже собранного — мерка для того, насколько далеко от буквы
  /// разрешено промахнуться следующей частью.
  Rect? get _filledBounds {
    Rect? result;
    for (final item in _filled) {
      final bounds = item.part.bounds;
      result = result == null ? bounds : result.expandToInclude(bounds);
    }
    return result;
  }

  /// Штрихи, нарисованные для текущей, ещё не собранной части.
  List<DrawingStroke> get _pendingStrokes =>
      _controller.strokes.sublist(_consumedStrokes);

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    _mergeController.duration = widget.mergeDuration;

    if (widget.placeholder != oldWidget.placeholder ||
        widget.placeholderPadding != oldWidget.placeholderPadding ||
        widget.mode != oldWidget.mode) {
      _resolvedShape = null;
      _resolvedFor = null;
      _cancelMerge();
      _resetProgress();
    }

    if (widget.controller != oldWidget.controller) {
      _detachController();
      _initController();
      return;
    }

    _applyOverrides();
  }

  void _initController() {
    _controller =
        widget.controller ?? (_internalController = DrawingController());
    _applyOverrides();
    _finishedRepaint.value = _controller.strokes.length;
    _controller.addListener(_onControllerChanged);
    _controller.attachChecker(_check);
  }

  void _detachController() {
    _controller.removeListener(_onControllerChanged);
    _controller.detachChecker(_check);
    _internalController?.dispose();
    _internalController = null;
  }

  /// Параметры виджета сильнее настроек контроллера — иначе при внешнем
  /// контроллере [DrawingCanvas.strokeWidth] молча ни на что не влияет.
  void _applyOverrides() {
    final color = widget.color;
    final strokeWidth = widget.strokeWidth;
    if (color != null) _controller.color = color;
    if (strokeWidth != null) _controller.strokeWidth = strokeWidth;
  }

  void _onControllerChanged() {
    final count = _controller.strokes.length;

    // Отмена/очистка ниже уже собранной части откатывает и её заливку.
    if (count < _consumedStrokes) {
      var changed = false;
      while (_filled.isNotEmpty && count < _filled.last.strokeCount) {
        _filled.removeLast();
        changed = true;
      }
      if (changed) {
        _cancelMerge();
        _bestCoverage = 0;
        setState(() {
          if (_filled.isEmpty) _anchored = null;
          _publishProgress();
        });
      }
    }

    if (_merge != null && count != _finishedRepaint.value) _cancelMerge();
    _finishedRepaint.value = count;
  }

  void _resetProgress() {
    _bestCoverage = 0;
    if (_filled.isEmpty && _anchored == null) return;
    setState(() {
      _filled.clear();
      _anchored = null;
    });
    _publishProgress();
  }

  void _publishProgress() {
    final parts = _activeShape?.parts;
    widget.onProgress?.call(
      TracingProgress(
        completed: _filled.length,
        total: _partCount,
        nextLabel: parts != null && _filled.length < parts.length
            ? parts[_filled.length].label
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _detachController();
    _mergeController.dispose();
    _finishedRepaint.dispose();
    super.dispose();
  }

  ResolvedTracingShape? _resolveShape(Size size) {
    final shape = widget.placeholder;
    if (shape == null || size.isEmpty) return null;
    if (_resolvedFor != size || _resolvedShape == null) {
      _resolvedShape = shape.resolve(size, padding: widget.placeholderPadding);
      _resolvedFor = size;
    }
    _syncPen(_resolvedShape);
    return _resolvedShape;
  }

  /// Перо фигуры известно только после раскладки: оно масштабируется вместе
  /// с буквой. Само значение нужно уже в этом кадре, а вот контроллеру его
  /// отдаём следующим — трогать его слушателей посреди layout нельзя.
  void _syncPen(ResolvedTracingShape? shape) {
    final pen = widget.strokeWidth ?? shape?.strokeWidth;
    if (pen == null || pen == _penWidth) return;

    _penWidth = pen;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.strokeWidth = pen;
    });
  }

  /// Сверяет ввод с фигурой и, если совпало, запускает слияние.
  ///
  /// В [TracingMode.tracing] сверяется вся буква целиком, в
  /// [TracingMode.freehand] — только текущая, ещё не собранная часть.
  TracingMatchResult _check() {
    final shape = _activeShape;
    if (shape == null || shape.parts.isEmpty) {
      return _emptyResult(TracingMatchStatus.noShape);
    }

    final freehand = widget.mode == TracingMode.freehand;
    final target = freehand ? shape.parts[_filled.length] : shape.whole;
    final strokes = freehand ? _pendingStrokes : _controller.strokes;
    if (strokes.isEmpty) return _emptyResult(TracingMatchStatus.noInput);

    // Первую часть по памяти рисуют где угодно и любого размера — сверяем
    // форму, а не место на холсте. Дальше буква уже закреплена там, где её
    // нарисовали, и остальные части сверяются относительно неё.
    // Этой частью буква встаёт на место: её выравнивание уходит в якорь,
    // а сами штрихи после этого уже лежат в нужной системе координат.
    final anchoring = freehand && _anchored == null;

    final alignment = !freehand
        ? const TracingAlignment.identity()
        : anchoring
        // Первую часть рисуют где угодно и любого размера.
        ? widget.matcher.align(target: target, strokes: strokes)
        // Дальше буква стоит на своём месте, но точки всё равно ставят
        // на глаз — им разрешён небольшой общий сдвиг.
        : widget.matcher.alignDots(
            target: target,
            strokes: strokes,
            penWidth: _penWidth,
            reference: _filledBounds,
          );

    final result = widget.matcher.match(
      target: target,
      strokes: strokes,
      alignment: alignment,
      penWidth: _penWidth,
      structural: freehand,
    );
    if (result.isMatch) {
      _anchorTo(alignment);
      _startMerge(
        _activeShape!.parts[_filled.length],
        strokes,
        anchoring ? const TracingAlignment.identity() : alignment,
      );
    } else if (freehand && widget.discardMisses && _filled.isNotEmpty) {
      // Только когда буква уже заякорена. Пока первая часть не собрана,
      // положение свободно, и фрагмент невозможно отличить от промаха:
      // выравнивание одинаково натягивает на букву и половину основы,
      // и случайную черту. Там пусть решает пользователь кнопкой.
      _discardIfMiss(result);
    }

    widget.onChecked?.call(result);
    return result;
  }

  /// Штрих оставляем, только если он продвинул часть: иначе случайная
  /// линия навсегда обнулит точность и часть уже никогда не соберётся.
  void _discardIfMiss(TracingMatchResult result) {
    if (!result.isChecked) return;

    final helped =
        result.coverage > _bestCoverage + 0.001 &&
        result.accuracy >= widget.matcher.keepAccuracy;

    if (helped) {
      _bestCoverage = result.coverage;
    } else {
      _controller.undo();
    }
  }

  TracingMatchResult _emptyResult(TracingMatchStatus status) {
    final result = TracingMatchResult.empty(status);
    widget.onChecked?.call(result);
    return result;
  }

  /// Переносит букву туда, где её нарисовали: обратное к выравниванию,
  /// которым мы её примеряли. После этого форма уже никуда не поедет —
  /// пользователь видит свою букву на своём месте, и точки ставит к ней.
  void _anchorTo(TracingAlignment alignment) {
    if (_anchored != null || alignment.isIdentity) return;
    _anchored = _resolvedShape?.transformed(
      alignment.inverseScale,
      alignment.inverseOffset,
    );
  }

  void _startMerge(
    ResolvedTracingPart target,
    List<DrawingStroke> strokes,
    TracingAlignment alignment,
  ) {
    setState(() {
      _merge = _MergeState(
        sources: List.of(strokes),
        targets: [
          for (final stroke in widget.matcher.project(
            target: target,
            strokes: strokes,
            alignment: alignment,
          ))
            stroke.copyWith(width: _penWidth ?? target.strokeWidth),
        ],
        part: target,
        strokeCount: _controller.strokes.length,
        inkColor: strokes.last.color,
      );
    });

    _mergeController
      ..reset()
      ..forward().then((_) {
        if (!mounted) return;
        final merge = _merge;
        if (merge == null) return;
        _completeMerge(merge);
      });
  }

  /// Слияние доиграло: часть окончательно залита, её штрихи «съедены».
  void _completeMerge(_MergeState merge) {
    setState(() {
      _filled.add(
        _FilledPart(part: merge.part, strokeCount: merge.strokeCount),
      );
      _merge = null;
      _bestCoverage = 0;
    });

    widget.onPartCompleted?.call(merge.part);
    _publishProgress();

    if (_filled.length >= _partCount) widget.onMerged?.call();
  }

  /// Мгновенно доводит слияние до конца.
  void _finalizeMerge() {
    final merge = _merge;
    if (merge == null) return;
    _mergeController.stop();
    _mergeController.value = 1;
    _completeMerge(merge);
  }

  void _cancelMerge() {
    if (_merge == null) return;
    _mergeController.stop();
    _mergeController.value = 0;
    setState(() => _merge = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final shape = _resolveShape(size);

        // Переподключаемся на каждом кадре: initState при hot reload не
        // выполняется, и без этого после перезагрузки check() отвечал бы
        // «холста нет». Присваивание идемпотентно.
        _controller.attachChecker(_check);

        return RepaintBoundary(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Container(
              color: widget.backgroundColor,
              child: CustomPaint(
                painter: _BackgroundPainter(
                  controller: _controller,
                  repaint: Listenable.merge([_finishedRepaint, _mergeProgress]),
                  guide: widget.mode == TracingMode.tracing ? shape : null,
                  placeholderColor: widget.placeholderColor,
                  filled: List.of(_filled),
                  inkColor: _controller.color,
                  penWidth: _penWidth,
                  skipStrokes: _consumedStrokes,
                  merge: _merge,
                  mergeProgress: _mergeProgress,
                ),
                foregroundPainter: _CurrentStrokePainter(_controller),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _activePointer != null) return;
    // Начали новый штрих поверх незаконченной анимации — доигрывать нечего,
    // но и терять уже засчитанную часть нельзя.
    _finalizeMerge();
    _activePointer = event.pointer;
    _controller.startStroke(event.localPosition);
    widget.onStrokeStart?.call();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _controller.extendStroke(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _controller.extendStroke(event.localPosition);
    _controller.endStroke();

    final stroke = _controller.strokes.isEmpty
        ? null
        : _controller.strokes.last;
    if (stroke != null) widget.onStrokeEnd?.call(stroke);

    // По памяти рисуют без кнопки: часть засчитывается сразу, как только
    // её удалось узнать.
    if (widget.mode == TracingMode.freehand && _filled.length < _partCount) {
      _check();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _controller.cancelStroke();
  }
}

/// Слияние: откуда штрихи едут, куда приезжают и чем заливается часть.
class _MergeState {
  final List<DrawingStroke> sources;
  final List<DrawingStroke> targets;
  final ResolvedTracingPart part;

  /// Сколько всего штрихов нарисовано к моменту слияния.
  final int strokeCount;

  final Color inkColor;

  _MergeState({
    required this.sources,
    required this.targets,
    required this.part,
    required this.strokeCount,
    required this.inkColor,
  });
}

/// Собранная часть и число штрихов, которыми её нарисовали.
class _FilledPart {
  final ResolvedTracingPart part;
  final int strokeCount;

  const _FilledPart({required this.part, required this.strokeCount});
}

/// Нижний слой: фигура-подсказка и уже завершённые штрихи. Список штрихов
/// читается в момент отрисовки, иначе слой застынет на снимке из build().
class _BackgroundPainter extends CustomPainter {
  final DrawingController controller;

  /// Бледный контур для обводки. В режиме по памяти — null.
  final ResolvedTracingShape? guide;
  final Color placeholderColor;

  /// Уже собранные части: рисуются вместо штрихов, которыми их нарисовали.
  final List<_FilledPart> filled;
  final Color inkColor;

  /// Перо, которым рисует пользователь: им же заливаются части, иначе
  /// готовая буква окажется толще или тоньше нарисованной линии.
  final double? penWidth;

  final int skipStrokes;

  final _MergeState? merge;
  final Animation<double> mergeProgress;

  _BackgroundPainter({
    required this.controller,
    required Listenable repaint,
    required this.guide,
    required this.placeholderColor,
    required this.filled,
    required this.inkColor,
    required this.penWidth,
    required this.skipStrokes,
    required this.merge,
    required this.mergeProgress,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    guide?.paint(canvas, placeholderColor, strokeWidth: penWidth);

    for (final item in filled) {
      item.part.paint(canvas, inkColor, strokeWidth: penWidth);
    }

    final strokes = controller.strokes;
    final merge = this.merge;

    if (merge == null) {
      DrawingPainter(
        strokes: skipStrokes == 0 ? strokes : strokes.sublist(skipStrokes),
      ).paint(canvas, size);
      return;
    }

    final t = mergeProgress.value;

    DrawingPainter(
      strokes: [
        for (
          var i = 0;
          i < merge.targets.length && i < merge.sources.length;
          i++
        )
          DrawingStroke.lerp(merge.sources[i], merge.targets[i], t),
      ],
    ).paint(canvas, size);

    // Во второй половине проявляем часть целиком: она дорисовывает то,
    // чего пользователь чуть-чуть не дотянул, — без рывка в конце.
    final fill = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    if (fill > 0) {
      merge.part.paint(
        canvas,
        merge.inkColor.withValues(alpha: fill),
        strokeWidth: penWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.guide != guide ||
      oldDelegate.placeholderColor != placeholderColor ||
      oldDelegate.filled.length != filled.length ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.penWidth != penWidth ||
      oldDelegate.skipStrokes != skipStrokes ||
      oldDelegate.merge != merge;
}

/// Верхний слой: только штрих, который рисуется прямо сейчас.
class _CurrentStrokePainter extends CustomPainter {
  final DrawingController controller;

  _CurrentStrokePainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = controller.currentStroke;
    if (stroke == null) return;
    DrawingPainter(strokes: [stroke]).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_CurrentStrokePainter oldDelegate) =>
      oldDelegate.controller != controller;
}
