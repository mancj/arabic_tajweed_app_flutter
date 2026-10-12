import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../resources/ui_text_styles.dart';
import '../app_haptics.dart';

/// Целые числа листаются вверх, уменьшаясь при удалении от центра окна.
/// Один общий проход идёт от начального числа к [value].
/// [initialValue] задаёт начало только при первом показе. Без него первое
/// значение показывается сразу; следующие изменения плавно прокручиваются.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    required this.value,
    this.initialValue,
    this.style,
    this.textScaler,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.enableHaptics = false,
    super.key,
  });

  final int value;
  final int? initialValue;
  final TextStyle? style;
  final TextScaler? textScaler;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final bool enableHaptics;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with WidgetsBindingObserver {
  late double _from;
  late double _position;
  late Duration _duration;
  late Duration _delay;
  late Curve _curve;
  int _generation = 0;
  int _digits = 1;
  bool _hasMinus = false;
  bool _reducedMotion = false;
  late int _lastReached;
  bool _finalHapticHandled = false;
  bool _visible = true;
  bool _appActive = true;
  bool _suppressNextFeedback = false;

  @override
  void initState() {
    super.initState();
    _from = (widget.initialValue ?? widget.value).toDouble();
    _position = _from;
    _rememberRange();
    _lastReached = _reachedNumber(_position);
    _appActive =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    // При том же направлении сохраняем даже незавершённый переход между
    // цифрами. При развороте начинаем с числа, занимающего большую часть окна.
    final sameDirection =
        (oldWidget.value - _from).sign == (widget.value - _position).sign;
    _from = sameDirection ? _position : _position.roundToDouble();
    _position = _from;
    _generation++;
    _rememberRange();
    _lastReached = _reachedNumber(_position);
    _finalHapticHandled = false;
    _suppressNextFeedback = !_visible || !_appActive;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (visible != _visible) _suppressNextFeedback = true;
    _visible = visible;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && !_reducedMotion) {
      _from = widget.value.toDouble();
      _position = widget.value.toDouble();
      _generation++;
    }
    _reducedMotion = reducedMotion;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive) _suppressNextFeedback = true;
    _appActive = active;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _reachedNumber(double position) =>
      widget.value >= _from ? position.floor() : position.ceil();

  void _feedbackForPosition(double position) {
    final reached = _reachedNumber(position);
    if (reached == _lastReached) return;
    _lastReached = reached;
    final isFinal = reached == widget.value;
    if (isFinal) {
      if (_finalHapticHandled) return;
      _finalHapticHandled = true;
    }
    final suppress = _suppressNextFeedback;
    if (_visible && _appActive) _suppressNextFeedback = false;
    if (!mounted ||
        !widget.enableHaptics ||
        !_visible ||
        !_appActive ||
        suppress) {
      return;
    }
    // После пропущенных кадров отклик получает только актуальное целое число:
    // цикл по пропущенным значениям устроил бы очередь вибраций.
    isFinal ? AppHaptics.heavy() : AppHaptics.tick();
  }

  void _rememberRange() {
    _duration = widget.duration;
    _delay = widget.delay.isNegative ? Duration.zero : widget.delay;
    _curve = widget.curve;
    for (final number in [_from.floor(), _from.ceil(), widget.value]) {
      final text = number.toString();
      _hasMinus = _hasMinus || number < 0;
      _digits = math.max(_digits, text.replaceFirst('-', '').length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style ?? UITextStyles.semibold20);
    final textScaler = widget.textScaler ?? MediaQuery.textScalerOf(context);
    final size = _textSize(style, textScaler);
    final animate =
        !_reducedMotion && _from != widget.value && _duration > Duration.zero;
    if (!animate) {
      _from = widget.value.toDouble();
      _position = _from;
      _feedbackForPosition(_position);
    }

    return Semantics(
      label: '${widget.value}',
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: size,
        child: ClipRect(
          child: animate
              ? const SizedBox.expand()
                    .animate(key: ValueKey(_generation))
                    .custom(
                      begin: _from,
                      end: widget.value.toDouble(),
                      duration: _duration,
                      delay: _delay,
                      curve: _curve,
                      builder: (context, position, child) {
                        _position = position;
                        _feedbackForPosition(position);
                        return _numbers(position, size, style, textScaler);
                      },
                    )
              : _numbers(_position, size, style, textScaler),
        ),
      ),
    );
  }

  Size _textSize(TextStyle style, TextScaler textScaler) {
    var digitWidth = 0.0;
    var minusWidth = 0.0;
    var height = 0.0;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    );
    // Максимальная ширина цифры резервирует все промежуточные числа без
    // обхода диапазона. Размер не сжимается в конце прохода или при смене 10→9.
    for (final glyph in '0123456789-'.split('')) {
      painter.text = TextSpan(text: glyph, style: style);
      painter.layout();
      height = math.max(height, painter.height);
      if (glyph == '-') {
        minusWidth = painter.width;
      } else {
        digitWidth = math.max(digitWidth, painter.width);
      }
    }
    painter.dispose();
    return Size(
      (digitWidth * _digits + (_hasMinus ? minusWidth : 0)).ceilToDouble(),
      height.ceilToDouble(),
    );
  }

  Widget _numbers(
    double position,
    Size size,
    TextStyle style,
    TextScaler textScaler,
  ) {
    final ascending = widget.value >= _from;
    final current = ascending ? position.floor() : position.ceil();
    final phase = (ascending ? position - current : current - position).clamp(
      0.0,
      1.0,
    );
    Widget number(int value, double offset) => Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, offset * size.height),
        child: Center(
          child: Transform.scale(
            scale: 1 - .65 * Curves.easeInOut.transform(offset.abs()),
            child: Text(
              '$value',
              style: style,
              textScaler: textScaler,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        number(current, -phase),
        if (phase > 0 && current != widget.value)
          number(current + (ascending ? 1 : -1), 1 - phase),
      ],
    );
  }
}
