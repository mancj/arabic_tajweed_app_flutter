import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'particle_motion.dart';

/// Одна геометрия для заполненных сегментов кольца и источника искр.
@immutable
class SegmentedRingGeometry {
  const SegmentedRingGeometry({
    this.count = 7,
    this.gap = .07,
    this.inset = 4,
    this.startAngle = -math.pi / 2,
  }) : assert(count > 0),
       assert(gap >= 0 && gap * 2 < math.pi * 2 / count),
       assert(inset >= 0);

  /// Количество отдельных сегментов кольца.
  final int count;

  /// Отступ каждого края сегмента в радианах; зазор между ними равен gap * 2.
  final double gap;

  /// Отступ линии кольца от ближайшего края виджета в логических пикселях.
  final double inset;

  /// Начало кольца в радианах: 0 — справа, -pi / 2 — сверху.
  final double startAngle;

  /// Угловой шаг от начала одного сегмента до начала следующего.
  double get step => math.pi * 2 / count;

  /// Длина видимой дуги сегмента в радианах, без отступов по краям.
  double get sweep => step - gap * 2;

  double segmentStart(int index) => startAngle + index * step + gap;

  double radiusFor(Size size) => math.max(0, size.shortestSide / 2 - inset);

  Rect rectFor(Size size) => Rect.fromCircle(
    center: size.center(Offset.zero),
    radius: radiusFor(size),
  );

  /// На границе сегментов источник остаётся на конце последнего
  /// заполненного сегмента, затем переходит через зазор к следующему.
  double angleAtProgress(double progress) {
    final position = progress.clamp(0.0, 1.0) * count;
    final index = (position.ceil() - 1).clamp(0, count - 1);
    return segmentStart(index) + sweep * (position - index).clamp(0.0, 1.0);
  }

  Offset pointAtProgress(Size size, double progress) {
    final angle = angleAtProgress(progress);
    return size.center(Offset.zero) +
        Offset(math.cos(angle), math.sin(angle)) * radiusFor(size);
  }
}

/// Искры из растущего конца кольца. После заполнения точки медленно
/// расходятся наружу по всей окружности; уже выпущенные продолжают свой полёт.
class RingSparks extends StatefulWidget {
  const RingSparks({
    required this.progress,
    required this.color,
    this.minRadius = .5,
    this.maxRadius = 1,
    this.activeEmissionRate = 18,
    this.floatingEmissionRate = 3,
    this.maxParticles = 48,
    this.speed = 1,
    this.geometry = const SegmentedRingGeometry(),
    this.enabled = true,
    this.seed = 17,
    super.key,
  }) : assert(minRadius >= 0),
       assert(maxRadius >= minRadius),
       assert(maxRadius < double.infinity),
       assert(activeEmissionRate >= 0 && activeEmissionRate < double.infinity),
       assert(
         floatingEmissionRate >= 0 && floatingEmissionRate < double.infinity,
       ),
       assert(maxParticles >= 0),
       assert(speed >= 0 && speed < double.infinity);

  /// Заполнение кольца от 0 до 1; определяет точку рождения и режим полёта.
  final ValueListenable<double> progress;

  /// Цвет искр; прозрачность дополнительно меняется в течение их жизни.
  final Color color;

  /// Минимальный радиус новых искр в логических пикселях, не диаметр.
  final double minRadius;

  /// Максимальный радиус новых искр в логических пикселях.
  /// Радиус каждой искры выбирается случайно между minRadius и maxRadius.
  /// Изменение диапазона влияет на новые искры, уже летящие сохраняют размер.
  final double maxRadius;

  /// Новых искр в секунду, пока кольцо заполняется. 0 отключает их появление.
  final double activeEmissionRate;

  /// Новых искр в секунду при спокойном парении по заполненному кольцу.
  /// Видимое количество также зависит от длительности жизни искр.
  final double floatingEmissionRate;

  /// Максимум одновременно живых искр. 0 очищает их и останавливает эффект.
  final int maxParticles;

  /// Множитель скорости полёта и затухания: 1 — обычная, 2 — вдвое быстрее.
  /// Не меняет частоту появления новых искр. 0 приостанавливает весь эффект
  /// без очистки уже выпущенных искр; смена скорости не сдвигает их мгновенно.
  final double speed;

  /// Геометрия кольца, по которой источник искр совпадает с краем дуги.
  final SegmentedRingGeometry geometry;

  /// Включает эффект; false очищает искры и останавливает их часы.
  final bool enabled;

  /// Начальное значение генератора случайности для повторяемого разброса искр.
  final int seed;

  @override
  State<RingSparks> createState() => _RingSparksState();
}

class _RingSparksState extends State<RingSparks>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Частицы продолжают рождаться и лететь после конца заполнения.
  // Общие часы нужны для всех точек; отдельные контроллеры им не нужны.
  late final Ticker _ticker = createTicker(_onFrame);

  // Выбирает размер, длительность и отклонение каждой новой искры.
  late math.Random _random = math.Random(widget.seed);

  // Последнее заполнение из внешнего источника, ограниченное диапазоном 0–1.
  late double _progress = widget.progress.value.clamp(0.0, 1.0);

  // Снимок для рисования; обновляет только слой искр, без перестройки экрана.
  final _frame = ValueNotifier<_SparkFrame>(const _SparkFrame(0, []));

  // Живые искры с сохранёнными точками рождения и параметрами полёта.
  final _sparks = <_Spark>[];

  // Время предыдущего кадра; null после паузы предотвращает скачок времени.
  Duration? _lastTick;

  // Время полёта в секундах; не увеличивается, пока эффект приостановлен.
  double _clock = 0;

  // Дробный остаток количества новых искр между кадрами.
  double _spawnCarry = 0;

  // Переход от активного вылета (0) к редкому спокойному парению (1).
  late double _floating = _progress >= 1 ? 1 : 0;

  // Экран видим, его тикеры включены и системные анимации разрешены.
  bool _visible = false;

  // Приложение активно; уход в фон приостанавливает полёт.
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    widget.progress.addListener(_onProgress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (MediaQuery.disableAnimationsOf(context)) _clear();
    _syncTicker();
  }

  @override
  void didUpdateWidget(RingSparks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
      _onProgress();
    }
    if (oldWidget.seed != widget.seed) _random = math.Random(widget.seed);
    if (oldWidget.activeEmissionRate != widget.activeEmissionRate ||
        oldWidget.floatingEmissionRate != widget.floatingEmissionRate) {
      _spawnCarry = 0;
    }
    if (_sparks.length > widget.maxParticles) {
      _sparks.removeRange(0, _sparks.length - widget.maxParticles);
      _frame.value = _SparkFrame(_clock, List.unmodifiable(_sparks));
    }
    if (!widget.enabled) _clear();
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  void _onProgress() {
    final next = widget.progress.value.clamp(0.0, 1.0);
    if (next < _progress) {
      _clear();
      _floating = 0;
    }
    _progress = next;
    // Источник может обновляться при построении родителя. Его слушатель
    // только сохраняет значение: ни экран, ни счётчик не перестраиваются.
    _syncTicker();
  }

  void _clear() {
    _sparks.clear();
    _spawnCarry = 0;
    _frame.value = _SparkFrame(_clock, const []);
  }

  void _syncTicker() {
    final available =
        widget.enabled && widget.speed > 0 && _visible && _resumed;
    final mayEmit =
        (widget.activeEmissionRate > 0 && _floating < 1) ||
        (widget.floatingEmissionRate > 0 && (_floating > 0 || _progress >= 1));
    final shouldRun =
        available &&
        _progress > 0 &&
        widget.maxParticles > 0 &&
        (mayEmit || _sparks.isNotEmpty);
    if (!shouldRun && _progress >= 1) _floating = 1;
    if (shouldRun && !_ticker.isActive) {
      _lastTick = null;
      _spawnCarry = 0;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
      _spawnCarry = 0;
    }
  }

  void _onFrame(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    // После паузы не выпускаем накопившиеся точки одним залпом.
    if (previous == null) return;
    final dt = ((elapsed - previous).inMicroseconds / 1e6).clamp(0.0, .05);
    _clock += dt * widget.speed;
    if (_progress >= 1) {
      _floating = math.min(1, _floating + dt / .8);
    }
    _sparks.removeWhere((spark) => _clock - spark.born >= spark.duration);
    final rate =
        widget.activeEmissionRate +
        (widget.floatingEmissionRate - widget.activeEmissionRate) * _floating;
    _spawnCarry += dt * rate;
    while (rate > 0 &&
        _spawnCarry >= 1 &&
        _sparks.length < widget.maxParticles) {
      _spawnCarry -= 1;
      _sparks.add(_birth());
    }
    _spawnCarry = rate == 0 ? 0 : math.min(_spawnCarry, 1);
    _frame.value = _SparkFrame(_clock, List.unmodifiable(_sparks));
    _syncTicker();
  }

  double _between(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  _Spark _birth() {
    // При заполнении источник следует за концом дуги; после него новые
    // искры рождаются на всех сегментах, без попадания в пустые зазоры.
    final sourceProgress = _progress >= 1 ? _random.nextDouble() : _progress;
    final angle = widget.geometry.angleAtProgress(sourceProgress);
    final direction = angle + _between(-.55, .55) * (1 - _floating);
    final outward = _between(.16, .32) * (1 - _floating) + .05 * _floating;
    return _Spark(
      born: _clock,
      // Координаты в радиусах кольца: при смене размера полёт не прыгает
      // к новому движущемуся источнику.
      origin: Offset(math.cos(angle), math.sin(angle)),
      outward: Offset(math.cos(direction), math.sin(direction)) * outward,
      duration:
          _between(1.05, 1.45) * (1 - _floating) + _between(3, 4) * _floating,
      rise:
          _between(.08, .18) * (1 - _floating) + _between(.25, .48) * _floating,
      drift:
          _between(-.05, .05) * (1 - _floating) +
          _between(-.12, .12) * _floating,
      radius: _between(widget.minRadius, widget.maxRadius),
      floating: _floating,
    );
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ringSize = constraints.biggest;
          // Полёт выходит за кольцо. Реальный холст с запасом сохраняет
          // точки при снимке слоя и его растровом кэшировании.
          final margin = 80 + widget.maxRadius;
          final width = ringSize.width + margin * 2;
          final height = ringSize.height + margin * 2;
          return OverflowBox(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _RingSparkPainter(
                  frame: _frame,
                  color: widget.color,
                  geometry: widget.geometry,
                  ringSize: ringSize,
                ),
                child: SizedBox(width: width, height: height),
              ),
            ),
          );
        },
      ),
    ),
  );
}

@immutable
class _Spark {
  const _Spark({
    required this.born,
    required this.origin,
    required this.outward,
    required this.duration,
    required this.rise,
    required this.drift,
    required this.radius,
    this.floating = 0,
  });

  /// Момент рождения в секундах общих часов эффекта.
  final double born;

  /// Точка рождения относительно центра, в единицах радиуса кольца.
  final Offset origin;

  /// Направление и дальность вылета наружу, в единицах радиуса кольца.
  final Offset outward;

  /// Полная длительность жизни искры в секундах.
  final double duration;

  /// Дальность плавного движения, как доля радиуса кольца:
  /// вверх при заполнении, наружу вдоль радиуса при спокойном парении.
  final double rise;

  /// Боковое отклонение, как доля радиуса кольца; знак задаёт сторону.
  /// При парении идёт по касательной к кольцу, при заполнении — по горизонтали.
  final double drift;

  /// Радиус конкретной искры в логических пикселях.
  final double radius;

  /// Режим в момент рождения: 0 — активный подъём, 1 — спокойный вылет
  /// по радиусу. Сохранённое значение не меняет полёт уже выпущенной искры.
  final double floating;
}

class _SparkFrame {
  const _SparkFrame(this.clock, this.sparks);

  /// Текущее время эффекта в секундах для расчёта возраста искр.
  final double clock;

  /// Неизменяемый список искр, которые нужно нарисовать в этом кадре.
  final List<_Spark> sparks;
}

class _RingSparkPainter extends CustomPainter {
  _RingSparkPainter({
    required this.frame,
    required this.color,
    required this.geometry,
    required this.ringSize,
  }) : super(repaint: frame);

  /// Снимки полёта; их обновление вызывает перерисовку холста.
  final ValueListenable<_SparkFrame> frame;

  /// Базовый цвет искр до появления и затухания.
  final Color color;

  /// Геометрия исходного кольца для расчёта положения искр.
  final SegmentedRingGeometry geometry;

  /// Размер кольца без внешнего запаса холста, в логических пикселях.
  final Size ringSize;

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = frame.value;
    final center = size.center(Offset.zero);
    final ringRadius = geometry.radiusFor(ringSize);
    final paint = Paint()..isAntiAlias = true;
    for (final spark in snapshot.sparks) {
      final progress = ((snapshot.clock - spark.born) / spark.duration).clamp(
        0.0,
        1.0,
      );
      final opacity = ParticleMotion.opacity(
        progress: progress,
        duration: spark.duration,
        fadeInDuration: .2,
      );
      if (opacity <= .01) continue;
      final rise = ParticleMotion.rise(progress);
      final travel = spark.rise * rise;
      final drift = spark.drift * ParticleMotion.drift(progress);
      final activeMotion = Offset(drift, -travel);
      final tangent = Offset(-spark.origin.dy, spark.origin.dx);
      final floatingMotion = spark.origin * travel + tangent * drift;
      final point =
          spark.origin +
          spark.outward * rise +
          Offset.lerp(activeMotion, floatingMotion, spark.floating)!;
      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawCircle(center + point * ringRadius, spark.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingSparkPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.color != color ||
      oldDelegate.geometry != geometry ||
      oldDelegate.ringSize != ringSize;
}
