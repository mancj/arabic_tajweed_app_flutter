import 'dart:async';
import 'dart:math' as math;

import 'package:arabic_tajweed_app/app/widgets/ui_kit/animated_background_shapes.dart';
import 'package:bokeh_lava_gradient/bokeh_lava_gradient.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tilt/flutter_tilt.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/animated_counter.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/ring_sparks.dart';

/// Недельный рубеж: дата относится к достигнутой неделе, а не к просмотру.
class WeeklyStreakPage extends StatefulWidget {
  const WeeklyStreakPage({this.achievedOn, this.onContinue, super.key});

  static const routeName = '/weekly-streak';

  final DateTime? achievedOn;
  final VoidCallback? onContinue;

  @override
  State<WeeklyStreakPage> createState() => _WeeklyStreakPageState();
}

class _WeeklyStreakPageState extends State<WeeklyStreakPage>
    with WidgetsBindingObserver {
  late final DateTime _achievedOn;
  Timer? _ambientTimer;
  bool _active = true;
  bool _ambientPlaying = true;
  bool _leaving = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    final date = (widget.achievedOn ?? DateTime.now()).toLocal();
    _achievedOn = DateTime(date.year, date.month, date.day);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    // Bokeh-фон останавливается независимо от парящих искр.
    _ambientTimer = Timer(4.seconds, () {
      if (mounted) setState(() => _ambientPlaying = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _active = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ambientTimer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (_leaving) return;
    _leaving = true;
    if (widget.onContinue case final callback?) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _appear(Widget child, {int delay = 0}) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child.animate().fadeIn(
      delay: delay.ms,
      duration: 450.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _action() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = TextPainter(
            text: TextSpan(
              text: 'Продолжить путь',
              style: UITextStyles.semibold16Compact,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: math.max(1, constraints.maxWidth - 32));
          final height = math.max(56.0, ((text.height + 24) / 8).ceil() * 8.0);
          text.dispose();
          return Semantics(
            button: true,
            label: 'Продолжить путь',
            onTap: _continue,
            excludeSemantics: true,
            child: NextButton(
              title: 'Продолжить путь',
              height: height,
              glassProminent: true,
              onTap: _continue,
            ),
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final badgeSize = MediaQuery.sizeOf(context).height < 740 ? 200.0 : 264.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UIColors.isDarkTheme
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: AppScaffold(
        title: MediaQuery.textScalerOf(context).scale(22) <= 32
            ? 'Стрик'
            : null,
        onBack: _continue,
        bottomBar: _action(),
        builder: (context, insets) => Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: TickerMode(
                  enabled: !reducedMotion && _ambientPlaying && _active,
                  child: RepaintBoundary(
                    child: BokehLavaGradient(
                      baseColor: UIColors.pageBackground,
                      colors: [
                        UIColors.backgroundShapes1,
                        UIColors.primary,
                        UIColors.backgroundShapes2,
                      ],
                      blobCount: 6,
                      speed: .25,
                      blurStrength: .18,
                      blobOpacity: UIColors.isDarkTheme ? .18 : .12,
                      minBlobRadius: .5,
                      maxBlobRadius: 1.1,
                      targetFps: 30,
                    ),
                  ),
                ),
              ),
            ),
            ColoredBox(color: UIColors.pageBackground.withValues(alpha: .35)),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: insets,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      minHeight: math.max(
                        0,
                        constraints.maxHeight - insets.vertical,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _WeekBadge(
                            size: badgeSize,
                            reducedMotion: reducedMotion,
                          ),
                          const Margin.vertical(32),
                          _appear(
                            Semantics(
                              header: true,
                              child: Text(
                                'Неделя занятий',
                                style: UITextStyles.semibold29,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            delay: 150,
                          ),
                          const Margin.vertical(12),
                          _appear(
                            Text(
                              '«Самое любимое из деяний перед Аллахом — это постоянное, пусть даже и небольшое»',
                              style: UITextStyles.regular15.copyWith(
                                color: UIColors.secondary1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            delay: 250,
                          ),
                          const Margin.vertical(32),
                          _CompletedWeek(
                            achievedOn: _achievedOn,
                            reducedMotion: reducedMotion,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBadge extends StatefulWidget {
  const _WeekBadge({required this.size, required this.reducedMotion});

  final double size;
  final bool reducedMotion;

  @override
  State<_WeekBadge> createState() => _WeekBadgeState();
}

class _WeekBadgeState extends State<_WeekBadge> {
  static const _fillDelay = Duration(milliseconds: 150);
  static const _fillDuration = Duration(milliseconds: 1500);
  static const _countDuration = Duration(milliseconds: 1000);
  static const _fillCurve = Curves.easeInOutCubic;
  static const _impactDuration = Duration(milliseconds: 840);

  static const _geometry = SegmentedRingGeometry(gap: 0.03);
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final reducedMotion = widget.reducedMotion;
    if (reducedMotion) _progress.value = 1;
    final child = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Число — часть фиксированной эмблемы. Обычные подписи экрана
              // сохраняют системный размер текста; эмблема масштабируется целиком.
              AnimatedCounter(
                value: 7,
                initialValue: 0,
                enableHaptics: true,
                duration: _countDuration * 2,
                delay: _fillDelay,
                curve: _fillCurve,
                textScaler: TextScaler.noScaling,
                style: UITextStyles.scaled(
                  UITextStyles.semibold144Compact,
                  size / 264,
                ).copyWith(color: UIColors.text),
              ),
              const Margin.vertical(4),
              Text(
                'дней подряд',
                textScaler: TextScaler.noScaling,
                style: UITextStyles.monoSemibold14,
              ),
            ],
          ),
        ),
        RingSparks(
          progress: _progress,
          activeEmissionRate: 12,
          floatingEmissionRate: 4,
          maxParticles: 32,
          minRadius: 1,
          maxRadius: 1.5,
          geometry: _geometry,
          color: UIColors.primary,
        ),
      ],
    );
    Widget badge = CustomPaint(
      painter: _WeekRing(
        progress: 1,

        color: UIColors.primary,
        geometry: _geometry,
      ),
      child: child,
    );
    if (!reducedMotion) {
      badge = child
          .animate()
          .custom(
            delay: _fillDelay,
            duration: _fillDuration,
            curve: _fillCurve,
            builder: (context, value, child) {
              _progress.value = value;
              return CustomPaint(
                painter: _WeekRing(
                  progress: value,
                  color: UIColors.primary,
                  geometry: _geometry,
                ),
                child: child,
              );
            },
          )
          .custom(
            delay: _fillDelay + _fillDuration,
            duration: _impactDuration,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              // Короткий пульс эмблемы и расходящаяся за ней волна
              // создают ощущение удара о фон.
              return CustomPaint(
                painter: _WeekImpact(progress: value, color: UIColors.primary),
                child: Transform.scale(
                  scale: 1 + .12 * math.sin(math.pi * value),
                  child: child,
                ),
              );
            },
          );
    }
    const shapeSize = 400.0;
    final shapes = AnimatedBackgroundShapes(
      color: UIColors.primary20,
      showCap: false,
    );
    return Semantics(
      label: '7 дней подряд',
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                minHeight: shapeSize,
                maxHeight: shapeSize,
                minWidth: shapeSize,
                maxWidth: shapeSize,
                child: reducedMotion ? shapes : Tilt(child: shapes),
              ),
            ),
          ),
          SizedBox.square(dimension: size, child: badge),
        ],
      ),
    );
  }
}

class _WeekImpact extends CustomPainter {
  const _WeekImpact({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final radius = (size.shortestSide / 2 - 4) * (1 + .4 * progress);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: .6 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_WeekImpact oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

class _WeekRing extends CustomPainter {
  const _WeekRing({
    required this.progress,
    required this.color,
    required this.geometry,
  });

  final double progress;
  final Color color;
  final SegmentedRingGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = geometry.radiusFor(size);
    final rect = geometry.rectFor(size);
    canvas.drawCircle(
      center,
      radius - 8,
      Paint()..color = color.withValues(alpha: .04),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < geometry.count; index++) {
      final angle = geometry.segmentStart(index);
      paint.color = color.withValues(alpha: .12);
      canvas.drawArc(rect, angle, geometry.sweep, false, paint);
      final part = (progress * geometry.count - index).clamp(0.0, 1.0);
      if (part == 0) continue;
      paint.color = color;
      canvas.drawArc(rect, angle, geometry.sweep * part, false, paint);
    }
  }

  @override
  bool shouldRepaint(_WeekRing oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      geometry != oldDelegate.geometry;
}

class _CompletedWeek extends StatelessWidget {
  const _CompletedWeek({required this.achievedOn, required this.reducedMotion});

  static const _labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  final DateTime achievedOn;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final diameter = ((constraints.maxWidth - 6 * 8) / 7).clamp(24.0, 36.0);
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        spacing: 12,
        children: List.generate(7, (index) {
          final day = DateTime(
            achievedOn.year,
            achievedOn.month,
            achievedOn.day - 6 + index,
          );
          final last = index == 6;
          Widget marker = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _labels[day.weekday - 1],
                style: UITextStyles.regular12.copyWith(
                  color: last ? UIColors.text : UIColors.secondary1,
                ),
              ),
              const Margin.vertical(8),
              Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: last ? UIColors.primary : UIColors.primary20,
                ),
                child:
                    SvgPicture.asset(
                      UISVGAssets.fire,
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        last ? UIColors.primaryButtonText : UIColors.primary,
                        BlendMode.srcIn,
                      ),
                    ).animate().fadeIn(
                      duration: 200.ms,
                      delay: (1100 + index * 200).ms,
                    ).scaleXY(begin: .5),
              ),
            ],
          );
          if (!reducedMotion) {
            marker = marker
                .animate()
                .fadeIn(
                  curve: Curves.easeOutBack,
                  delay: (1000 + index * 100).ms,
                  duration: 450.ms,
                )
                .scaleXY(begin: 1.2, end: .9, duration: 200.ms)
                .then(delay: 100.ms)
                .scaleXY(begin: 1, end: 1.2, duration: 500.ms);
          }
          return Semantics(
            label: '${day.day}.${day.month}.${day.year}: занятие выполнено',
            excludeSemantics: true,
            child: marker,
          );
        }),
      );
    },
  );
}
