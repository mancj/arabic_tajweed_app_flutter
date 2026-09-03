import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

/// Декоративная «волна» — несколько полупрозрачных холмов, наложенных друг
/// на друга, и тонкая линия-основание, растворяющаяся у краёв.
///
/// Пока это просто плавная псевдослучайная анимация: у каждого бугра своя
/// частота дыхания и лёгкий горизонтальный дрейф. Когда появится реальный
/// звук, достаточно будет кормить виджет уровнями через [amplitude] (или
/// расширить [_Bump] до уровня из аудиопотока) — форма и отрисовка не
/// изменятся.
class WaveformWidget extends StatefulWidget {
  /// Высота полосы вместе с линией-основанием.
  final double height;

  /// Сколько слоёв холмов накладывается друг на друга.
  /// Пересечения складываются по альфе и дают более тёмные участки.
  final int layers;

  final Color color;

  /// Общий множитель амплитуды, 0 — ровная линия. Сюда позже придёт
  /// громкость звука.
  final double amplitude;

  final bool animate;

  /// Форма холмов детерминирована сидом: один и тот же сид — один и тот же
  /// силуэт.
  final int seed;

  const WaveformWidget({
    super.key,
    this.height = 80,
    this.layers = 4,
    this.color = UIColors.waveform,
    this.amplitude = 1,
    this.animate = true,
    this.seed = 7,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  /// Один длинный проход вместо перезапуска: колебания и так периодичны,
  /// а так не видно шва на стыке циклов.
  static const _cycle = Duration(seconds: 120);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  late List<List<_Bump>> _layers = _buildLayers();

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seed != oldWidget.seed || widget.layers != oldWidget.layers) {
      _layers = _buildLayers();
    }
    if (widget.animate != oldWidget.animate) {
      widget.animate ? _controller.repeat() : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<List<_Bump>> _buildLayers() {
    final random = math.Random(widget.seed);

    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);

    return List.generate(widget.layers, (layer) {
      // Дальние слои ниже и шире, ближние — острее и выше.
      final depth = widget.layers == 1 ? 1.0 : layer / (widget.layers - 1);
      final count = 4 + random.nextInt(3);

      return List.generate(count, (_) {
        return _Bump(
          center: between(0.06, 0.94),
          width: between(0.035, 0.075) * (1.3 - 0.4 * depth),
          height: between(0.3, 0.7) + 0.5 * depth,
          speed: between(0.05, 0.14),
          phase: between(0, 2 * math.pi),
          drift: between(-0.03, 0.03),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          layers: _layers,
          time: _controller,
          cycleSeconds: _cycle.inSeconds.toDouble(),
          color: widget.color,
          amplitude: widget.amplitude,
        ),
      ),
    );
  }
}

/// Один бугор: гауссиана, у которой амплитуда дышит, а центр слегка гуляет.
class _Bump {
  /// Позиция и ширина — в долях ширины виджета, высота — в долях его высоты.
  final double center;
  final double width;
  final double height;

  /// Оборотов колебания в секунду.
  final double speed;
  final double phase;
  final double drift;

  const _Bump({
    required this.center,
    required this.width,
    required this.height,
    required this.speed,
    required this.phase,
    required this.drift,
  });

  /// Амплитуда не падает до нуля: холмы дышат, а не исчезают.
  double amplitudeAt(double t) =>
      height * (0.62 + 0.38 * math.sin(2 * math.pi * speed * t + phase));

  double centerAt(double t) =>
      center + drift * math.sin(2 * math.pi * speed * 0.37 * t + phase * 1.7);

  double valueAt(double x, double t) {
    final d = (x - centerAt(t)) / width;
    return amplitudeAt(t) * math.exp(-d * d);
  }
}

class _WaveformPainter extends CustomPainter {
  /// Сколько альфы добавляет один слой: пересечения складываются и дают
  /// градации серого без отдельных цветов на каждый холм.
  static const _layerAlpha = 0.16;
  static const _lineWidth = 1.0;
  static const _step = 2.0;

  final List<List<_Bump>> layers;
  final Animation<double> time;
  final double cycleSeconds;
  final Color color;
  final double amplitude;

  _WaveformPainter({
    required this.layers,
    required this.time,
    required this.cycleSeconds,
    required this.color,
    required this.amplitude,
  }) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value * cycleSeconds;
    final baseline = size.height - _lineWidth;
    final peak = baseline * amplitude;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final bumps in layers) {
      paint.color = color.withValues(alpha: _layerAlpha);
      canvas.drawPath(_layerPath(bumps, size, baseline, peak, t), paint);
    }

    _paintBaseline(canvas, size, baseline);
  }

  Path _layerPath(
    List<_Bump> bumps,
    Size size,
    double baseline,
    double peak,
    double t,
  ) {
    final path = Path()..moveTo(0, baseline);

    for (var x = 0.0; x <= size.width; x += _step) {
      final u = x / size.width;
      var value = 0.0;
      for (final bump in bumps) {
        value += bump.valueAt(u, t);
      }
      // Мягкое насыщение вместо clamp: сумма нескольких бугров легко
      // переваливает за единицу, и жёсткая обрезка давала плоские срезы
      // по верхней границе.
      path.lineTo(x, baseline - (1 - math.exp(-value)) * peak);
    }

    return path
      ..lineTo(size.width, baseline)
      ..close();
  }

  /// Линия-основание: к краям растворяется, поэтому полоса не выглядит
  /// обрезанной по границе виджета.
  void _paintBaseline(Canvas canvas, Size size, double baseline) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.18, 0.82, 1],
      ).createShader(rect);

    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.layers != layers ||
      old.color != color ||
      old.amplitude != amplitude ||
      old.cycleSeconds != cycleSeconds;
}
