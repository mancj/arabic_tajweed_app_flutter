import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rive/rive.dart' as rive;

import '../../diagnostics/app_diagnostics.dart';
import '../../resources/ui_resources.dart';

/// Орбитальные кольца из Rive. Достаточно вставить `OrbitalRingsWidget()`.
/// Размер задаёт родитель; виджет сохраняет квадратные пропорции.
class OrbitalRingsWidget extends StatefulWidget {
  const OrbitalRingsWidget({
    this.color = const Color(0xFFFFFFFF),
    this.thickness = 1.1,
    this.ringThickness,
    this.dashThickness,
    this.playing = true,
    this.onLoaded,
    super.key,
  }) : assert(thickness >= 1 && thickness <= 3),
       assert(
         ringThickness == null || (ringThickness >= 1 && ringThickness <= 3),
       ),
       assert(
         dashThickness == null || (dashThickness >= 1 && dashThickness <= 3),
       );

  final Color color;

  /// Общая толщина для прежних вызовов: 1 — исходный вид, до 3 — толще.
  /// Отдельные значения ниже имеют приоритет.
  final double thickness;

  /// Толщина четырёх колец. Если не задана, используется [thickness].
  final double? ringThickness;

  /// Толщина вращающихся мелких штрихов. Если не задана, используется [thickness].
  final double? dashThickness;
  final bool playing;
  final VoidCallback? onLoaded;

  @override
  State<OrbitalRingsWidget> createState() => _OrbitalRingsWidgetState();
}

class _OrbitalRingsWidgetState extends State<OrbitalRingsWidget> {
  // В экспортированном Rive фон нарисован чёрным. Яркость штрихов становится
  // прозрачностью: чёрные пиксели исчезают, серые остаются полупрозрачными.
  static const _blackToAlpha = ColorFilter.matrix(<double>[
    0,
    0,
    0,
    0,
    255,
    0,
    0,
    0,
    0,
    255,
    0,
    0,
    0,
    0,
    255,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
  ]);

  late final _loader = rive.FileLoader.fromAsset(
    'assets/rive/orbital_rings.riv',
    riveFactory: rive.Factory.flutter,
  );

  Widget _applyThickness(Widget child) {
    final ringThickness = widget.ringThickness ?? widget.thickness;
    final dashThickness = widget.dashThickness ?? widget.thickness;
    if (ringThickness == dashThickness) {
      return _dilate(child, ringThickness);
    }
    return _SplitThickness(
      ringThickness: ringThickness,
      dashThickness: dashThickness,
      child: child,
    );
  }

  Widget _dilate(Widget child, double thickness) {
    if (thickness == 1) return child;
    final radius = (thickness - 1) * 1.5;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.dilate(radiusX: radius, radiusY: radius),
      child: child,
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: rive.RiveWidgetBuilder(
      fileLoader: _loader,
      artboardSelector: const rive.ArtboardNamed('Orbital Rings'),
      stateMachineSelector: const rive.StateMachineNamed('Orbit Player'),
      onLoaded: (_) => widget.onLoaded?.call(),
      onFailed: (error, stackTrace) => AppDiagnostics.talker.handle(
        error,
        stackTrace,
        'Rive: не удалось загрузить орбитальные кольца',
      ),
      builder: (context, state) => switch (state) {
        rive.RiveLoading() => Center(
          child: CircularProgressIndicator(color: UIColors.primary),
        ),
        rive.RiveLoaded() => TickerMode(
          enabled: widget.playing && !MediaQuery.disableAnimationsOf(context),
          child: IgnorePointer(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(widget.color, BlendMode.modulate),
              child: _applyThickness(
                ColorFiltered(
                  colorFilter: _blackToAlpha,
                  child: rive.RiveWidget(
                    controller: state.controller,
                    fit: rive.Fit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        rive.RiveFailed() => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить анимацию.\n'
              'Подробности — в журнале ошибок.',
              textAlign: TextAlign.center,
              style: UITextStyles.regular15,
            ),
          ),
        ),
      },
    ),
  );
}

// Кольца в файле неподвижны. При разной толщине убираем их из кадра Rive
// и рисуем отдельно; движущиеся штрихи остаются в единственном Rive-виджете.
class _SplitThickness extends SingleChildRenderObjectWidget {
  const _SplitThickness({
    required this.ringThickness,
    required this.dashThickness,
    required super.child,
  });

  final double ringThickness;
  final double dashThickness;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSplitThickness(
        ringThickness: ringThickness,
        dashThickness: dashThickness,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSplitThickness renderObject,
  ) {
    renderObject
      ..ringThickness = ringThickness
      ..dashThickness = dashThickness;
  }
}

class _RenderSplitThickness extends RenderProxyBox {
  _RenderSplitThickness({
    required double ringThickness,
    required double dashThickness,
  }) : _ringThickness = ringThickness,
       _dashThickness = dashThickness;

  double _ringThickness;
  double get ringThickness => _ringThickness;
  set ringThickness(double value) {
    if (_ringThickness == value) return;
    _ringThickness = value;
    markNeedsPaint();
  }

  double _dashThickness;
  double get dashThickness => _dashThickness;
  set dashThickness(double value) {
    if (_dashThickness == value) return;
    _dashThickness = value;
    markNeedsPaint();
  }

  Path _dashMask() {
    final scale = size.width / 600;
    final center = Offset(size.width / 2, size.height * 288 / 600);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final (radius, halfWidth) in <(double, double)>[
      (160, 3.5),
      (196, 3.5),
      (228, 3.5),
      (246, 3.5),
    ]) {
      final outer = (radius + halfWidth) * scale;
      final inner = (radius - halfWidth) * scale;
      path
        ..addOval(Rect.fromCircle(center: center, radius: outer))
        ..addOval(Rect.fromCircle(center: center, radius: inner));
    }
    return path;
  }

  void _paintDashes(PaintingContext context, Offset offset) {
    final path = _dashMask();
    final radius = (dashThickness - 1) * 1.5;
    void paintClipped(PaintingContext innerContext, Offset innerOffset) {
      innerContext.pushClipPath(
        true,
        innerOffset,
        Offset.zero & size,
        path,
        (clippedContext, clippedOffset) =>
            clippedContext.paintChild(child!, clippedOffset),
      );
    }

    if (radius == 0) {
      paintClipped(context, offset);
    } else {
      context.pushLayer(
        ImageFilterLayer(
          imageFilter: ui.ImageFilter.dilate(radiusX: radius, radiusY: radius),
        ),
        paintClipped,
        offset,
        childPaintBounds: (Offset.zero & size).inflate(radius).shift(offset),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    _paintDashes(context, offset);
    final canvas = context.canvas;
    final scale = size.width / 600;
    final center = offset + Offset(size.width / 2, size.height * 288 / 600);
    final addedWidth = (ringThickness - 1) * 3;
    for (final (ringRadius, width, opacity) in <(double, double, double)>[
      (160, 1.6, 1),
      (196, 1.5, 0.36),
      (228, 1.3, 0.15),
      (246, 1.1, 0.05),
    ]) {
      canvas.drawCircle(
        center,
        ringRadius * scale,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * scale + addedWidth,
      );
    }
  }
}
