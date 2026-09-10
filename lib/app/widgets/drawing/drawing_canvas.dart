import 'package:arabic_tajweed_app/app/resources/ui_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_haptics.dart';
import 'demo_animation.dart';
import 'drawing_controller.dart';
import 'drawing_painter.dart';
import 'drawing_stroke.dart';
import 'merge_animation.dart';
import 'stroke_projector.dart';
import 'tracing_matcher.dart';
import 'tracing_miss_counter.dart';
import 'tracing_shape.dart';

export 'drawing_controller.dart';
export 'drawing_stroke.dart';
export 'tracing_matcher.dart';
export 'tracing_shape.dart';

/// Как холст работает с фигурой.
/// Части в обоих режимах проверяются одинаково: по очереди, сразу после
/// штриха, и рисовать их можно где угодно и любого размера — сверяется
/// форма, а не место на холсте. Режим решает только, видно ли контур,
/// а значит — куда собранная буква встаёт.
enum TracingMode {
  /// Фигура показана бледным контуром. Штрихи съезжаются к нему: контур
  /// и есть место буквы, рисунок к нему только приводится.
  tracing,

  /// Фигура скрыта: пользователь пишет по памяти, и буква остаётся там,
  /// где он её нарисовал. Первая часть закрепляет это место.
  freehand,
}

/// Чем закончился штрих для текущей части буквы.
enum TracingStrokeOutcome {
  /// Часть собрана: штрихи сливаются с ней.
  completed,

  /// Часть ещё не готова, но штрих её продвинул — фрагмент части из
  /// нескольких линий или кусок линии под контуром. Остаётся на холсте.
  progressed,

  /// Штрих не приблизил часть к готовности. При [DrawingCanvas.discardMisses]
  /// стирается сразу: иначе он портил бы все следующие попытки.
  missed,
}

/// Холст, на котором пользователь рисует пальцем.
/// Линия сглаживается фильтром + сплайном, концы и стыки — круглые.
class DrawingCanvas extends StatefulWidget {
  final DrawingController? controller;

  /// Чернила пользователя. Если задан, перекрывает цвет контроллера.
  final Color? color;

  /// Цвет собранной буквы: ею заливаются части, которые уже сошлись.
  /// Не задан — красится чернилами, и буква выглядит нарисованной рукой.
  final Color? filledColor;

  /// Цвет полностью собранной буквы. В него плавно переходит весь рисунок
  /// после последней правильно заполненной части.
  final Color? completedColor;

  /// Толщина пера в пикселях. Если не задана, перо берётся из фигуры
  /// ([TracingShape.strokeWidth], отмасштабированная под холст) — тогда
  /// нарисованная линия и залитая буква совпадают по толщине. Без фигуры
  /// и без явной толщины — [defaultStrokeWidth].
  ///
  /// Это единственное место, где толщина задаётся: контроллер её только
  /// хранит, холст записывает туда итог (см. [_DrawingCanvasState._syncPen]).
  final double? strokeWidth;

  /// Перо для холста без фигуры: свободное рисование.
  static const defaultStrokeWidth = 26.0;

  /// Во сколько раз перо толще линии фигуры. Чисто внешнее: чернила чуть
  /// шире контура накрывают бледную линию целиком, и обводка выглядит
  /// опрятно. На заливку не влияет — контур и собранная буква рисуются
  /// своей толщиной, и при слиянии штрих в неё же и утончается.
  final double penScale;

  /// Во сколько раз полоса измерения шире линии фигуры.
  ///
  /// Полоса — единица всего позиционного в [TracingMatcher]: от неё
  /// считаются и допуск на попадание, и отклонение. Одно число смягчает
  /// покрытие, точность и отклонение разом, не трогая порогов, и не
  /// касается сравнения форм — там размера не остаётся вовсе.
  ///
  /// Отдельно от [penScale], потому что это разные вещи. Обводят пальцем,
  /// и центр пера гуляет: на линии в 17px он уходит на 10–14px в стороны.
  /// Мерить такую обводку самой линией — требовать точности, которой
  /// у пальца нет. Раздувать ради этого видимое перо не годится: толстая
  /// линия в макете выглядит плохо.
  final double bandScale;

  final Color backgroundColor;

  /// Что делает холст с фигурой: показывает для обводки или прячет и
  /// принимает части по очереди.
  final TracingMode mode;

  /// Фигура-подсказка под штрихами: её пользователь обводит.
  final TracingShape? placeholder;
  final Color? placeholderColor;
  final double placeholderPadding;

  /// Правила, по которым ввод признаётся совпавшим с фигурой.
  final TracingMatcher matcher;

  /// Длительность анимации слияния штрихов с фигурой.
  final Duration mergeDuration;

  /// Показывать ли, как буква пишется: холст сам обводит текущую часть
  /// поверх контура, прежде чем за неё возьмётся человек. Про порядок
  /// частей и направление пера взяться иначе неоткуда — контур об этом
  /// молчит. Только под видимым контуром: по памяти это подсказка.
  final bool showDemo;

  /// Цвет показа. По умолчанию — цвет чернил: холст пишет тем же, чем
  /// потом будет писать человек. Отдельным цветом показ отличается от
  /// уже нарисованного — так понятнее, где чужая рука, а где своя.
  final Color? demoColor;

  /// Скорость показа, пикселей в секунду. Время считается от длины части,
  /// чтобы перо шло одинаково быстро и у алифа, и у сина.
  final double demoSpeed;

  /// Разгон и торможение пера в показе. Применяется к доле письма, а не
  /// ко всей анимации: выдержка и растворение идут ровно.
  final Curve demoCurve;

  /// Пауза между частями в показе: перо отрывают, прежде чем взяться за
  /// следующую. Без неё точка вырастает ровно там, где дописана основа,
  /// и читается её продолжением, а не отдельным движением.
  ///
  /// Во времени, но в длину показа переводится через [demoSpeed], чтобы
  /// пауза попала и в отрисовку, и в длительность из одного числа.
  final Duration demoPartGap;

  /// Убирать штрих, который не приблизил текущую часть к готовности. Иначе
  /// промах остаётся на холсте и портит точность всех следующих попыток.
  /// После первой части буква стоит на месте, и промах виден по покрытию.
  /// На первой части покрытие не судья: выравнивание натягивает на букву
  /// что угодно, — поэтому там промах отличают по форме, см. [_isFragment].
  final bool discardMisses;

  final bool enabled;

  /// Через сколько пикселей пути под пальцем повторяется тик вибрации.
  /// 0 — рисовать без отклика.
  final double hapticStep;

  final VoidCallback? onStrokeStart;
  final ValueChanged<DrawingStroke>? onStrokeEnd;

  /// Результат каждой проверки [DrawingController.check].
  final ValueChanged<TracingMatchResult>? onChecked;

  /// Чем закончился штрих: часть собрана, продвинута или промах.
  final ValueChanged<TracingStrokeOutcome>? onStrokeOutcome;

  /// Сколько промахов подряд по одной части холст терпит, прежде чем сам
  /// покажет, как пишется: очистит холст, откроет контур и запустит показ.
  /// Правило живёт в холсте, а не у экрана: иначе каждый экран с обводкой
  /// заводил бы его заново. 0 — не показывать никогда. См. SPEC.md §5.
  final int missesBeforeReveal;

  /// Холст показал, как пишется, после серии промахов. Урок здесь
  /// засчитывает ошибку; экран без оценок может просто сменить подсказку.
  final VoidCallback? onReveal;

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
    this.filledColor,
    this.completedColor,
    this.strokeWidth,
    this.penScale = 1.1,
    this.bandScale = 1.5,
    this.backgroundColor = UIColors.transparent,
    this.mode = TracingMode.tracing,
    this.placeholder,
    this.placeholderColor,
    this.placeholderPadding = 24,
    this.matcher = const TracingMatcher(),
    this.mergeDuration = const Duration(milliseconds: 250),
    this.showDemo = true,
    this.demoColor,
    this.demoSpeed = 350,
    this.demoCurve = Curves.easeOut,
    this.demoPartGap = const Duration(milliseconds: 100),
    this.discardMisses = true,
    this.enabled = true,
    this.hapticStep = 14,
    this.onStrokeStart,
    this.onStrokeEnd,
    this.onChecked,
    this.onStrokeOutcome,
    this.missesBeforeReveal = 3,
    this.onReveal,
    this.onPartCompleted,
    this.onProgress,
    this.onMerged,
  }) : super(key: key);

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas>
    with TickerProviderStateMixin {
  late DrawingController _controller;
  DrawingController? _internalController;

  late final _merge = MergeAnimation(
    vsync: this,
    duration: widget.mergeDuration,
  );
  late final _demo = DemoAnimation(vsync: this);

  /// Подтверждение успеха: после сборки всей буквы цвет переходит в зелёный.
  late final _completionColor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// Отдельный сигнал для нижнего слоя: завершённые штрихи перерисовываются
  /// только когда их список реально изменился, а не на каждое движение пальца.
  final _finishedRepaint = ValueNotifier<int>(0);

  /// Пауза между частями в длине показа.
  double get _demoGap =>
      widget.demoPartGap.inMicroseconds / 1e6 * widget.demoSpeed;

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
  /// Толщина линии фигуры: ею рисуются контур и собранные части.
  double? _penWidth;

  /// Толщина пера пользователя: только рисование.
  double? _inkWidth;

  /// Полоса, которой меряется попадание. Уходит в [TracingMatcher] тем же
  /// параметром, что и перо: там она и есть единица измерения.
  double? _bandWidth;
  int? _activePointer;

  /// Где палец был в момент последнего тика вибрации: от этой точки
  /// копится путь до следующего.
  Offset? _hapticFrom;

  /// Лучшее покрытие текущей части: по нему видно, помог ли новый штрих.
  double _bestCoverage = 0;

  late final _misses = TracingMissCounter(limit: widget.missesBeforeReveal);

  /// Контур открыт после серии промахов, хотя режим — по памяти.
  /// Держится до смены буквы или режима.
  bool _revealed = false;

  /// Холст сам стирает промах: это не «человек начал заново», и счёт
  /// промахов при таком опустевшем холсте сбрасывать нельзя.
  bool _discarding = false;

  /// Штрихи до этого индекса уже влиты в собранные части и отдельно
  /// не рисуются.
  int get _consumedStrokes => _filled.isEmpty ? 0 : _filled.last.strokeCount;

  int get _partCount => widget.placeholder?.parts.length ?? 0;

  /// Фигура, с которой сейчас сверяемся: закреплённая, если она уже есть.
  ResolvedTracingShape? get _activeShape => _anchored ?? _resolvedShape;

  /// Виден ли контур. От этого зависит, где окажется собранная буква.
  bool get _showsGuide => widget.mode == TracingMode.tracing || _revealed;

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

    _merge.duration = widget.mergeDuration;

    if (widget.placeholder != oldWidget.placeholder ||
        widget.placeholderPadding != oldWidget.placeholderPadding ||
        widget.mode != oldWidget.mode) {
      _resolvedShape = null;
      _resolvedFor = null;
      _revealed = false;
      _misses.reset();
      _merge.cancel();
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

  /// Цвет виджета сильнее настройки контроллера — иначе при внешнем
  /// контроллере [DrawingCanvas.color] молча ни на что не влияет.
  /// Толщиной распоряжается [_syncPen]: она зависит ещё и от раскладки.
  void _applyOverrides() {
    final color = widget.color;
    if (color != null) _controller.color = color;
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
        _merge.cancel();
        _completionColor.value = 0;
        _bestCoverage = 0;
        setState(() {
          if (_filled.isEmpty) _anchored = null;
          _publishProgress();
        });
      }
    }

    // Стёрли всё — начинают заново, и промахи прошлой попытки не в счёт.
    // Именно стёрли: штрихи были и пропали, а не «ещё ничего не нарисовано».
    if (count == 0 && _finishedRepaint.value > 0 && !_discarding) {
      _misses.reset();
    }

    // Холст снова чист под текущей частью — значит человек стёр начатое
    // и заходит заново. Тут показ и уместен.
    if (count == _consumedStrokes && !_controller.isDrawing) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _playDemo());
    }

    if (_merge.isActive && count != _finishedRepaint.value) _merge.cancel();
    _finishedRepaint.value = count;
  }

  void _resetProgress() {
    _bestCoverage = 0;
    _completionColor.value = 0;
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
    _demo.dispose();
    _merge.dispose();
    _completionColor.dispose();
    _finishedRepaint.dispose();
    super.dispose();
  }

  ResolvedTracingShape? _resolveShape(Size size) {
    final shape = widget.placeholder;
    if (shape == null || size.isEmpty) {
      _syncPen(null);
      return null;
    }
    if (_resolvedFor != size || _resolvedShape == null) {
      _resolvedShape = shape.resolve(size, padding: widget.placeholderPadding);
      _resolvedFor = size;
      // Раскладка идёт посреди сборки кадра, а показ трогает анимацию
      // и состояние: запускаем его следующим кадром.
      SchedulerBinding.instance.addPostFrameCallback((_) => _playDemo());
    }
    _syncPen(_resolvedShape);
    return _resolvedShape;
  }

  /// Перо фигуры известно только после раскладки: оно масштабируется вместе
  /// с буквой. Само значение нужно уже в этом кадре, а вот контроллеру его
  /// отдаём следующим — трогать его слушателей посреди layout нельзя.
  void _syncPen(ResolvedTracingShape? shape) {
    final pen =
        widget.strokeWidth ??
        shape?.strokeWidth ??
        DrawingCanvas.defaultStrokeWidth;
    if (pen == _penWidth) return;

    _penWidth = pen;
    _inkWidth = pen * widget.penScale;
    _bandWidth = pen * widget.bandScale;
    final ink = _inkWidth!;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.strokeWidth = ink;
    });
  }

  /// Сверяет очередную часть фигуры и, если совпало, запускает слияние.
  ///
  /// Часть рисуют где угодно и любого размера: выравнивание примеряет
  /// нарисованное к цели, а [TracingMatcher.match] судит уже приведённое.
  /// Совпало — буква встаёт на место и дальше держит его сама: остальным
  /// частям разрешён только небольшой общий сдвиг, чтобы точка попадала
  /// к своей букве, а не к соседнему углу холста.
  ///
  /// Годных исходов два, и это не придирка к порогам, а разные вопросы.
  /// «Та же форма?» — сравнение сигнатур, единственное, что можно спросить
  /// у буквы, нарисованной в стороне. «Попал по контуру?» — покрытие,
  /// точность и отклонение, и спросить это можно, только когда контур
  /// виден. Обводка пальцем в форму укладывается еле-еле: у сигнатуры
  /// зазор между законным вариантом (0.063) и ближайшей неверной формой
  /// (0.087) в две сотых, и дрожание руки его съедает. Зато по контуру
  /// такая обводка проходит с запасом — и это честный ответ, а не
  /// послабление: мимо буквы по покрытию с отклонением не пройдёшь.
  TracingMatchResult _check() {
    final shape = _activeShape;
    if (shape == null || shape.parts.isEmpty) {
      return _emptyResult(TracingMatchStatus.noShape);
    }

    final target = shape.parts[_filled.length];
    final strokes = _pendingStrokes;
    if (strokes.isEmpty) return _emptyResult(TracingMatchStatus.noInput);

    final anchoring = _anchored == null;

    final alignment = anchoring
        ? widget.matcher.align(target: target, strokes: strokes)
        : widget.matcher.alignDots(
            target: target,
            strokes: strokes,
            penWidth: _bandWidth,
            reference: _filledBounds,
          );

    var result = widget.matcher.match(
      target: target,
      strokes: strokes,
      alignment: alignment,
      penWidth: _bandWidth,
      structural: true,
    );

    // Куда едут штрихи при слиянии. К контуру — в его систему координат,
    // то есть через то же выравнивание, которым мы их узнали. К своему
    // месту — никуда: туда переехала сама фигура, а штрихи уже лежат как
    // надо. А попавшие в контур не едут вовсе: они и так на месте.
    var merge = _showsGuide || !anchoring
        ? alignment
        : const TracingAlignment.identity();

    if (!result.isMatch && _showsGuide) {
      // Тем же выравниванием, что и сравнение форм: вопрос не «где ты
      // это нарисовал», а «накрыл ли ты букву». Приведённое к месту
      // покрытие с точностью отвечают на него прямо, а отклонение не даёт
      // зачесть чужую форму — «W» на месте чаши обходит фигуру, но уходит
      // от неё далеко.
      final onGuide = widget.matcher.match(
        target: target,
        strokes: strokes,
        alignment: alignment,
        penWidth: _bandWidth,
      );
      if (onGuide.isMatch) result = onGuide;
    }

    if (result.isMatch) {
      _settle(alignment, anchoring: anchoring);
      _startMerge(_activeShape!.parts[_filled.length], strokes, merge);
      widget.onStrokeOutcome?.call(TracingStrokeOutcome.completed);
    } else {
      final helped = anchoring
          ? _isFragment(target, strokes)
          : _advancesCoverage(result);
      if (!helped && widget.discardMisses) {
        _discarding = true;
        _controller.undo();
        _discarding = false;
      }
      final outcome = helped
          ? TracingStrokeOutcome.progressed
          : TracingStrokeOutcome.missed;
      widget.onStrokeOutcome?.call(outcome);
      if (widget.missesBeforeReveal > 0 && _misses.register(outcome)) {
        _reveal();
      }
    }

    widget.onChecked?.call(result);
    return result;
  }

  /// Серия промахов: показываем, как пишется. Холст очищается, контур
  /// открывается и на чистом холсте сам запускается показ. По памяти это
  /// меняет и место буквы — теперь она встанет на контур, как при обводке.
  void _reveal() {
    _controller.clear();
    if (!_revealed) {
      setState(() => _revealed = true);
      _resolvedShape = null;
      _resolvedFor = null;
      _resetProgress();
    }
    widget.onReveal?.call();
  }

  /// Буква уже стоит на месте: штрих полезен, если поднял покрытие части
  /// и хоть наполовину лёг в её полосу. Иначе случайная линия навсегда
  /// обнулит точность, и часть уже никогда не соберётся.
  bool _advancesCoverage(TracingMatchResult result) {
    final helped =
        result.coverage > _bestCoverage + 0.001 &&
        result.accuracy >= widget.matcher.keepAccuracy;
    if (helped) _bestCoverage = result.coverage;
    return helped;
  }

  /// Первая часть ещё не закрепила букву, и по покрытию промах не отличить:
  /// выравнивание одинаково натягивает на букву и половину основы, и
  /// случайную черту. Зато отличить можно по форме: нарисованное похоже
  /// на одну из линий части или на её кусок. А под контуром штрих, лежащий
  /// на линии, — тоже не промах, как бы он ни выглядел сам по себе.
  bool _isFragment(ResolvedTracingPart target, List<DrawingStroke> strokes) {
    if (target.paths.isEmpty) return true;
    if (widget.matcher.isLineFragment(target, strokes)) return true;
    if (!_showsGuide) return false;
    final last = strokes.last;
    final onGuide = widget.matcher.match(
      target: target,
      strokes: [last],
      penWidth: _bandWidth,
    );
    return onGuide.accuracy >= widget.matcher.keepAccuracy;
  }

  TracingMatchResult _emptyResult(TracingMatchStatus status) {
    final result = TracingMatchResult.empty(status);
    widget.onChecked?.call(result);
    return result;
  }

  /// Закрепляет букву: после первой собранной части она уже никуда не едет,
  /// и следующие части сверяются относительно неё.
  ///
  /// Под видимым контуром местом буквы служит сам контур — фигура остаётся
  /// где стояла, а к ней приводят штрихи. Без контура наоборот: фигура
  /// переносится туда, где рисовал пользователь, обратным преобразованием
  /// к тому, которым мы её примеряли.
  void _settle(TracingAlignment alignment, {required bool anchoring}) {
    if (!anchoring) return;
    if (_showsGuide) {
      _anchored = _resolvedShape;
      return;
    }
    if (alignment.isIdentity) return;
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
    _merge.start(
      MergeState(
        sources: List.of(strokes),
        targets: [
          for (final stroke
              in StrokeProjector(widget.matcher.tracks(target)).project(
                strokes,
                alignment: alignment,
                strokeWidth: target.strokeWidth,
              ))
            stroke.copyWith(width: _penWidth ?? target.strokeWidth),
        ],
        part: target,
        strokeCount: _controller.strokes.length,
        inkColor: strokes.last.color,
      ),
      onComplete: _completeMerge,
    );
  }

  /// Показывает, как пишется текущая часть: холст обводит её сам, поверх
  /// контура. Нужен ровно там, где человек ещё не начал: начатую часть
  /// показ бы перекрывал, а по памяти он был бы подсказкой.
  /// Само движение — в [DemoAnimation]; здесь решается, уместен ли показ.
  void _playDemo() {
    if (!mounted) return;

    final shape = _activeShape;
    final from = _filled.length;

    if (shape == null ||
        from >= shape.parts.length ||
        !widget.showDemo ||
        !widget.enabled ||
        !_showsGuide ||
        _pendingStrokes.isNotEmpty ||
        _controller.isDrawing) {
      _demo.stop();
      return;
    }

    _demo.play(
      shape,
      from: from,
      gap: _demoGap,
      speed: widget.demoSpeed,
      strokeWidth: _penWidth,
    );
  }

  /// Слияние доиграло: часть окончательно залита, её штрихи «съедены».
  void _completeMerge(MergeState merge) {
    setState(() {
      _filled.add(
        _FilledPart(part: merge.part, strokeCount: merge.strokeCount),
      );
      _bestCoverage = 0;
    });
    _misses.partsDone(_filled.length);

    widget.onPartCompleted?.call(merge.part);
    _publishProgress();
    _playDemo();

    if (_filled.length >= _partCount) {
      _completionColor.forward(from: 0);
      widget.onMerged?.call();
    }
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
          // Холст забирает жест себе сразу, как только палец его коснулся.
          // Сам по себе Listener в арене жестов не участвует, и вертикальный
          // штрих по букве доставался заодно прокрутке страницы: буква
          // рисовалась, а экран под ней ехал. Выключенный холст жест не
          // забирает — по нему прокручивают, как по любой картинке.
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: widget.enabled
                ? <Type, GestureRecognizerFactory>{
                    EagerGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          EagerGestureRecognizer
                        >(EagerGestureRecognizer.new, (_) {}),
                  }
                : const <Type, GestureRecognizerFactory>{},
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
                    repaint: Listenable.merge([
                      _finishedRepaint,
                      _merge,
                      _demo,
                      _completionColor,
                    ]),
                    guide: _showsGuide ? shape : null,
                    placeholderColor:
                        widget.placeholderColor ?? UIColors.backgroundShapes1,
                    demo: _demo,
                    demoCurve: widget.demoCurve,
                    demoColor: widget.demoColor ?? UIColors.secondary2,
                    filled: List.of(_filled),
                    inkColor: widget.filledColor ?? _controller.color,
                    completedColor: widget.completedColor ?? UIColors.primary,
                    completionColor: _completionColor,
                    // Контур и собранные части — своей толщиной: перо шире
                    // только у пользователя.
                    penWidth: _penWidth,
                    skipStrokes: _consumedStrokes,
                    merge: _merge,
                  ),
                  foregroundPainter: _CurrentStrokePainter(_controller),
                  size: Size.infinite,
                ),
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
    _merge.finalize();
    // Человек взялся сам — показ больше не нужен и только мешал бы
    // смотреть на свою линию.
    _demo.stop();
    _activePointer = event.pointer;
    _hapticFrom = event.localPosition;
    // Отклик уже на касание: перо «легло на бумагу». Иначе точка —
    // касание без пути — проходила беззвучно, тик идёт только по длине.
    AppHaptics.tick();
    _controller.startStroke(event.localPosition);
    widget.onStrokeStart?.call();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _controller.extendStroke(event.localPosition);
    _tickHaptic(event.localPosition);
  }

  /// Тик вибрации раз в [DrawingCanvas.hapticStep] пикселей пути.
  /// Считается по сырому положению пальца, а не по сглаженной линии:
  /// отклик должен идти в такт руке, а не фильтру.
  void _tickHaptic(Offset at) {
    final from = _hapticFrom;
    final step = widget.hapticStep;
    if (from == null || step <= 0) return;
    if ((at - from).distance < step) return;
    _hapticFrom = at;
    AppHaptics.tick();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    // Позиция отрыва идёт прямо в endStroke, а не обычным движением:
    // подворот пальца при отрыве должен попасть под сглаживание хвоста,
    // а не в линию как есть.
    _controller.endStroke(event.localPosition);

    final stroke = _controller.strokes.isEmpty
        ? null
        : _controller.strokes.last;
    if (stroke != null) widget.onStrokeEnd?.call(stroke);

    // Кнопки для проверки нет ни в одном режиме: часть засчитывается
    // сразу, как только её удалось узнать.
    if (_filled.length < _partCount) _check();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _controller.cancelStroke();
  }
}

/// Собранная часть и число штрихов, которыми её нарисовали.
class _FilledPart {
  final ResolvedTracingPart part;
  final int strokeCount;

  const _FilledPart({required this.part, required this.strokeCount});
}

/// Нижний слой: контур, показ, собранные части и завершённые штрихи.
/// Список штрихов читается в момент отрисовки, иначе слой застынет на
/// снимке из build(). Показ и слияние рисуют себя сами: слой только
/// расставляет их по порядку — поверх подсказки, под рукой.
class _BackgroundPainter extends CustomPainter {
  final DrawingController controller;

  /// Бледный контур для обводки. В режиме по памяти — null.
  final ResolvedTracingShape? guide;
  final Color placeholderColor;

  final DemoAnimation demo;
  final Curve demoCurve;
  final Color demoColor;

  /// Уже собранные части: рисуются вместо штрихов, которыми их нарисовали.
  final List<_FilledPart> filled;
  final Color inkColor;
  final Color completedColor;
  final Animation<double> completionColor;

  /// Перо, которым рисует пользователь: им же заливаются части, иначе
  /// готовая буква окажется толще или тоньше нарисованной линии.
  final double? penWidth;

  final int skipStrokes;
  final MergeAnimation merge;

  _BackgroundPainter({
    required this.controller,
    required Listenable repaint,
    required this.guide,
    required this.placeholderColor,
    required this.demo,
    required this.demoCurve,
    required this.demoColor,
    required this.filled,
    required this.inkColor,
    required this.completedColor,
    required this.completionColor,
    required this.penWidth,
    required this.skipStrokes,
    required this.merge,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    guide?.paint(canvas, placeholderColor, strokeWidth: penWidth);
    demo.paint(
      canvas,
      color: demoColor,
      curve: demoCurve,
      strokeWidth: penWidth,
    );
    final filledColor = Color.lerp(
      inkColor,
      completedColor,
      completionColor.value,
    )!;
    for (final item in filled) {
      item.part.paint(canvas, filledColor, strokeWidth: penWidth);
    }
    merge.paint(
      canvas,
      size,
      strokes: controller.strokes,
      skipStrokes: skipStrokes,
      penWidth: penWidth,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.guide != guide ||
      oldDelegate.placeholderColor != placeholderColor ||
      oldDelegate.demo != demo ||
      oldDelegate.demoCurve != demoCurve ||
      oldDelegate.demoColor != demoColor ||
      oldDelegate.filled.length != filled.length ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.completedColor != completedColor ||
      oldDelegate.completionColor != completionColor ||
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
