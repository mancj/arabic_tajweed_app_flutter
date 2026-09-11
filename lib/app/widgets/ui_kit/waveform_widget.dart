import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Декоративная «волна» — несколько полупрозрачных контуров холмов,
/// наложенных друг на друга, и тонкая линия-основание, растворяющаяся у краёв.
///
/// Холмы всегда одни и те же: у каждого бугра своя частота дыхания и лёгкий
/// горизонтальный дрейф. Без звука они еле шевелятся, а на звучащей записи
/// [track] прыгают вверх-вниз по её громкости — новых фигур не появляется
/// и не заполняется слева направо.
///
/// Громкость берётся из пиков записи в точке воспроизведения. Пики снимает
/// нативный разбор файла, а он есть не везде; без них холмы просто
/// раскачиваются ровнее, но «звучат» тоже.
//
/// Настройка точек, поднимающихся над волной.
class WaveformParticles {
  /// Сколько точек может одновременно находиться над волной. Ноль отключает
  /// эффект.
  final int count;

  /// Сколько точки продолжают лететь и исчезать после остановки
  /// воспроизведения.
  final Duration duration;

  /// Длительность плавного появления точки в начале её полёта.
  final Duration fadeInDuration;

  /// Цвет точек, включая прозрачность. Если не задан, берётся цвет контура
  /// волны.
  final Color? color;

  /// Размер точки в логических пикселях. У каждой точки свой размер внутри
  /// этого диапазона.
  final double minRadius;
  final double maxRadius;

  const WaveformParticles({
    this.count = 14,
    this.duration = const Duration(seconds: 2),
    this.fadeInDuration = const Duration(milliseconds: 160),
    this.color,
    this.minRadius = 1.2,
    this.maxRadius = 2.4,
  }) : assert(count >= 0, 'Количество частиц не может быть отрицательным'),
       assert(
         minRadius > 0,
         'Минимальный размер частицы должен быть больше нуля',
       ),
       assert(
         minRadius <= maxRadius,
         'Минимальный размер частицы не больше максимального',
       );
}

/// Декоративная анимированная волна, связанная со звуком записи.
class WaveformWidget extends StatefulWidget {
  /// Высота полосы вместе с линией-основанием.
  final double height;

  /// Сколько слоёв холмов накладывается друг на друга.
  /// Пересечения складываются по альфе и дают более тёмные участки.
  final int layers;

  /// Цвет контуров холмов и линии-основания, включая прозрачность.
  final Color? strokeColor;

  /// Цвет заливки холмов, включая прозрачность. Если не задан, совпадает с
  /// [strokeColor].
  final Color? fillColor;

  /// Толщина контуров холмов и линии-основания.
  final double strokeWidth;

  /// Общий множитель амплитуды, 0 — ровная линия.
  final double amplitude;

  /// Высота холмов в тишине — доля высоты полосы.
  final double restHeight;

  /// Высота на пике громкости. Разница с [restHeight] и есть тот запас,
  /// на который волна подпрыгивает от звука; равные значения — не прыгает.
  final double loudHeight;

  /// Сколько бугров в слое. Точное число не задаётся: разное количество
  /// у соседних слоёв и делает силуэт неровным. Равные границы — строгое
  /// количество.
  final int minBumps;
  final int maxBumps;

  /// Ширина бугра — доля ширины полосы, разброс на слой. Чем меньше бугров,
  /// тем шире их стоит брать, иначе полоса выглядит пустой с редкими пиками.
  /// Дальние слои дополнительно шире ближних.
  final double minBumpWidth;
  final double maxBumpWidth;

  /// Высота бугра до насыщения. Единица — примерно две трети полосы: один
  /// бугор до верха не достаёт, потолок набирается их наложением. Поэтому
  /// при одном-двух буграх на слойих стоит брать заметно больше единицы.
  /// Ближние слои дополнительно выше дальних.
  final double minBumpHeight;
  final double maxBumpHeight;

  /// Звучащая запись. Null — волна всегда декоративная.
  final ValueListenable<AudioTrack>? track;

  final bool animate;

  /// Настройка поднимающихся точек над волной.
  final WaveformParticles particles;

  /// Форма холмов детерминирована сидом: один и тот же сид — один и тот же
  /// силуэт.
  final int seed;

  const WaveformWidget({
    super.key,
    this.height = 80,
    this.layers = 4,
    this.strokeColor,
    this.fillColor,
    this.strokeWidth = 1,
    this.amplitude = 1,
    this.restHeight = 0.72,
    this.loudHeight = 1,
    this.minBumps = 4,
    this.maxBumps = 6,
    this.minBumpWidth = 0.045,
    this.maxBumpWidth = 0.1,
    this.minBumpHeight = 0.3,
    this.maxBumpHeight = 0.7,
    this.track,
    this.animate = true,
    this.particles = const WaveformParticles(),
    this.seed = 7,
  }) : assert(restHeight <= loudHeight, 'В тишине волна не выше, чем на пике'),
       assert(strokeWidth > 0, 'Толщина контура должна быть больше нуля'),
       assert(minBumps >= 1 && minBumps <= maxBumps, 'Пустой диапазон бугров'),
       assert(
         minBumpWidth > 0 && minBumpWidth <= maxBumpWidth,
         'Пустой диапазон ширины',
       ),
       assert(
         minBumpHeight > 0 && minBumpHeight <= maxBumpHeight,
         'Пустой диапазон высоты',
       );

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  /// Собственные часы волны: время в них идёт быстрее, когда звук громче.
  /// Умножать на скорость сам `elapsed` нельзя — при смене множителя фаза
  /// прыгнула бы, и холмы дёрнулись.
  late final Ticker _ticker = createTicker(_onFrame);

  final _pulse = ValueNotifier<_Pulse>(
    const _Pulse(clock: 0, level: 0, particleLevel: 0),
  );

  /// Разгон резче спада: звук начинается мгновенно, а обрывать хвост так же
  /// резко нельзя — читается как сбой отрисовки.
  static const _attack = 18.0;
  static const _release = 5.0;

  /// Во сколько раз ускоряется дыхание холмов на полной громкости.
  static const _speedGain = 2.5;

  /// Пиков нет (веб, десктоп) — качаем на фиксированной громкости, иначе
  /// нажатие play не отзовётся ничем.
  static const _blindLevel = 0.55;

  Duration _lastTick = Duration.zero;

  late List<List<_Bump>> _layers = _buildLayers();
  late List<_Particle> _particleSeeds = _buildParticleSeeds();

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seed != oldWidget.seed ||
        widget.layers != oldWidget.layers ||
        widget.minBumps != oldWidget.minBumps ||
        widget.maxBumps != oldWidget.maxBumps ||
        widget.minBumpWidth != oldWidget.minBumpWidth ||
        widget.maxBumpWidth != oldWidget.maxBumpWidth ||
        widget.minBumpHeight != oldWidget.minBumpHeight ||
        widget.maxBumpHeight != oldWidget.maxBumpHeight) {
      _layers = _buildLayers();
    }
    if (widget.seed != oldWidget.seed ||
        widget.particles.count != oldWidget.particles.count ||
        widget.particles.minRadius != oldWidget.particles.minRadius ||
        widget.particles.maxRadius != oldWidget.particles.maxRadius) {
      _particleSeeds = _buildParticleSeeds();
    }
    if (widget.animate != oldWidget.animate) {
      widget.animate ? _ticker.start() : _ticker.stop();
    }
  }

  /// Сглаживает громкость и двигает часы. Экспоненциальное сглаживание по
  /// реальному dt, а не по номеру кадра: на просевшем фреймрейте иначе
  /// меняется сама скорость отклика.
  void _onFrame(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;

    final track = widget.track?.value ?? AudioTrack.silent;
    final target = !track.isPlaying
        ? 0.0
        : track.levels.isEmpty
        ? _blindLevel
        : track.level;

    final previous = _pulse.value;
    final rate = target > previous.level ? _attack : _release;
    final level =
        previous.level + (target - previous.level) * (1 - math.exp(-rate * dt));
    final particleDuration =
        widget.particles.duration.inMicroseconds /
        Duration.microsecondsPerSecond;
    final fadeInDuration =
        widget.particles.fadeInDuration.inMicroseconds /
        Duration.microsecondsPerSecond;
    final particleLevel = track.isPlaying
        ? math.min(1.0, previous.particleLevel + dt / fadeInDuration)
        : math.max(0.0, previous.particleLevel - dt / particleDuration);

    _pulse.value = _Pulse(
      clock: previous.clock + dt * (1 + _speedGain * level),
      level: level,
      particleLevel: particleLevel,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  List<List<_Bump>> _buildLayers() {
    final random = math.Random(widget.seed);

    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);

    return List.generate(widget.layers, (layer) {
      // Дальние слои ниже и шире, ближние — острее и выше.
      final depth = widget.layers == 1 ? 1.0 : layer / (widget.layers - 1);
      final count =
          widget.minBumps +
          random.nextInt(widget.maxBumps - widget.minBumps + 1);

      // Каждому бугру своя доля ширины, а разброс — только внутри неё.
      // На чистом случайном центре двух-трёх бугров хватало, чтобы все они
      // сошлись в одной половине полосы, и она выглядела перекошенной.
      final slot = 1 / count;

      // Слои сдвинуты друг относительно друга на треть доли: иначе при одном
      // бугре на слой все три садятся в середину, а края пустуют.
      final stagger = (depth - 0.5) * 0.7;

      return List.generate(count, (index) {
        final width =
            between(widget.minBumpWidth, widget.maxBumpWidth) *
            (1.3 - 0.4 * depth);
        final center = slot * (index + 0.5 + stagger + between(-0.12, 0.12));

        return _Bump(
          // Широкому бугру нужен отступ от края, иначе половина холма
          // остаётся за границей виджета и слоя как будто нет.
          center: center.clamp(
            math.min(width, 0.42),
            1 - math.min(width, 0.42),
          ),
          width: width,
          height:
              between(widget.minBumpHeight, widget.maxBumpHeight) *
              (0.75 + 0.5 * depth),
          speed: between(0.05, 0.14),
          phase: between(0, 2 * math.pi),
          drift: between(-0.06, 0.06),
          response: between(0.4, 1.6),
        );
      });
    });
  }

  List<_Particle> _buildParticleSeeds() {
    final random = math.Random(widget.seed ^ 0x51a7);

    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);

    return List.generate(
      widget.particles.count,
      (_) => _Particle(
        anchor: between(0.06, 0.94),
        phase: random.nextDouble(),
        duration: between(2.4, 3.2),
        drift: between(-0.045, 0.045),
        rise: between(0.22, 0.46),
        radius: between(widget.particles.minRadius, widget.particles.maxRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          layers: _layers,
          particleSeeds: _particleSeeds,
          pulse: _pulse,
          strokeColor: widget.strokeColor ?? UIColors.primary60,
          fillColor: widget.fillColor ?? UIColors.primary20,
          particles: widget.particles,
          strokeWidth: widget.strokeWidth,
          amplitude: widget.amplitude,
          restHeight: widget.restHeight,
          loudHeight: widget.loudHeight,
        ),
      ),
    );
  }
}

/// Кадр жизни волны: сколько прошло по её собственным часам и насколько
/// громко звучит запись прямо сейчас и сколько ещё виден след частиц.
class _Pulse {
  final double clock;
  final double level;
  final double particleLevel;

  const _Pulse({
    required this.clock,
    required this.level,
    required this.particleLevel,
  });
}

class _Bump {
  /// Позиция и ширина — в долях ширины виджета, высота — в долях его высоты.
  final double center;
  final double width;
  final double height;

  /// Оборотов колебания в секунду.
  final double speed;
  final double phase;
  final double drift;

  /// Насколько этот бугор отзывается на громкость. Разный у соседей, иначе
  /// на звуке весь силуэт растёт одной плитой.
  final double response;

  const _Bump({
    required this.center,
    required this.width,
    required this.height,
    required this.speed,
    required this.phase,
    required this.drift,
    required this.response,
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

/// Одна точка не хранит изменяемого состояния: её фаза вычисляется из часов
/// волны. Поэтому для эффекта не нужны отдельные контроллеры или виджеты.
class _Particle {
  final double anchor;
  final double phase;
  final double duration;
  final double drift;
  final double rise;
  final double radius;

  const _Particle({
    required this.anchor,
    required this.phase,
    required this.duration,
    required this.drift,
    required this.rise,
    required this.radius,
  });
}

class _WaveformPainter extends CustomPainter {
  static const _step = 2.0;

  /// Насколько громкость перекраивает форму сверх общего роста: соседние
  /// бугры тянутся по-разному, и силуэт не просто масштабируется.
  static const _shimmer = 0.5;

  /// Ближние слои откликаются на звук сильнее дальних — иначе весь силуэт
  /// ходит одной плитой.
  static const _depthResponse = 0.45;

  final List<List<_Bump>> layers;
  final List<_Particle> particleSeeds;
  final ValueListenable<_Pulse> pulse;
  final Color strokeColor;
  final Color? fillColor;
  final WaveformParticles particles;
  final double strokeWidth;
  final double amplitude;
  final double restHeight;
  final double loudHeight;

  _WaveformPainter({
    required this.layers,
    required this.particleSeeds,
    required this.pulse,
    required this.strokeColor,
    required this.fillColor,
    required this.particles,
    required this.strokeWidth,
    required this.amplitude,
    required this.restHeight,
    required this.loudHeight,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = pulse.value;
    final baseline = size.height - strokeWidth / 2;
    final peak = baseline * amplitude;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = strokeColor;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = fillColor ?? strokeColor;

    for (var i = 0; i < layers.length; i++) {
      final depth = layers.length == 1 ? 1.0 : i / (layers.length - 1);
      final loudness =
          frame.level * (1 - _depthResponse + _depthResponse * depth);
      final scale =
          restHeight + (loudHeight - restHeight) * loudness.clamp(0.0, 1.0);
      final layerPath = _layerPath(
        layers[i],
        size,
        baseline,
        peak * scale,
        frame.clock,
        loudness,
      );
      canvas.drawPath(
        Path.from(layerPath)
          ..lineTo(size.width, baseline)
          ..close(),
        fillPaint,
      );
      canvas.drawPath(layerPath, strokePaint);
    }

    _paintParticles(canvas, size, baseline, frame);
    _paintBaseline(canvas, size, baseline);
  }

  void _paintParticles(
    Canvas canvas,
    Size size,
    double baseline,
    _Pulse frame,
  ) {
    if (frame.particleLevel <= 0.01) return;

    final paint = Paint()..isAntiAlias = true;
    final color = particles.color ?? strokeColor;
    final fadeInDuration =
        particles.fadeInDuration.inMicroseconds /
        Duration.microsecondsPerSecond;
    for (final particle in particleSeeds) {
      final progress = (frame.clock / particle.duration + particle.phase) % 1;
      // Появление короткое, а перемещение быстрое уже в первом кадре: точка
      // не задерживается статично у основания. В конце она растворяется.
      final fadeIn = (progress * particle.duration / fadeInDuration).clamp(
        0.0,
        1.0,
      );
      final fadeOut = ((1 - progress) / 0.28).clamp(0.0, 1.0);
      final opacity = fadeIn * fadeOut * frame.particleLevel;
      if (opacity <= 0.01) continue;

      final x =
          size.width *
          (particle.anchor + particle.drift * math.sin(math.pi * progress))
              .clamp(0.02, 0.98);
      // Точка приходит из нижней границы и больше к ней не возвращается.
      final startY = baseline;
      final rise = 1 - math.pow(1 - progress, 3);
      final y = startY - size.height * particle.rise * rise;
      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawCircle(Offset(x, y), particle.radius, paint);
    }
  }

  Path _layerPath(
    List<_Bump> bumps,
    Size size,
    double baseline,
    double peak,
    double t,
    double loudness,
  ) {
    final path = Path()..moveTo(0, baseline);

    for (var x = 0.0; x <= size.width; x += _step) {
      final u = x / size.width;
      var value = 0.0;
      for (final bump in bumps) {
        value += bump.valueAt(u, t) * (1 + _shimmer * loudness * bump.response);
      }
      // Мягкое насыщение вместо clamp: сумма нескольких бугров легко
      // переваливает за единицу, и жёсткая обрезка давала плоские срезы
      // по верхней границе.
      path.lineTo(x, baseline - (1 - math.exp(-value)) * peak);
    }

    return path;
  }

  /// Линия-основание: к краям растворяется, поэтому полоса не выглядит
  /// обрезанной по границе виджета. В центре она имеет цвет [strokeColor].
  void _paintBaseline(Canvas canvas, Size size, double baseline) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [
          strokeColor.withValues(alpha: 0),
          strokeColor,
          strokeColor,
          strokeColor.withValues(alpha: 0),
        ],
        stops: const [0, 0.18, 0.82, 1],
      ).createShader(rect);

    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.layers != layers ||
      old.particleSeeds != particleSeeds ||
      old.strokeColor != strokeColor ||
      old.fillColor != fillColor ||
      old.particles != particles ||
      old.strokeWidth != strokeWidth ||
      old.amplitude != amplitude ||
      old.restHeight != restHeight ||
      old.loudHeight != loudHeight ||
      old.pulse != pulse;
}
