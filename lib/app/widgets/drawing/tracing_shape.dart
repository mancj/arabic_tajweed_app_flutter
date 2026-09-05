import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'stroke_signature.dart';

/// Часть фигуры, которую пользователь рисует за один заход: основа буквы,
/// диакритическая точка и т.д. Части проверяются и заполняются по очереди.
class TracingShapePart {
  final String id;

  /// Человекочитаемое название для подсказок: «основа», «точка».
  final String label;

  /// Линии части.
  final List<Path> paths;

  /// Точки части — заливаются кругами.
  final List<Offset> dots;

  const TracingShapePart({
    required this.id,
    required this.label,
    this.paths = const [],
    this.dots = const [],
  });
}

/// Фигура-подсказка: контур, который пользователь обводит или рисует по памяти.
///
/// Геометрия задаётся в произвольных «дизайнерских» единицах и подгоняется
/// под размер холста в [resolve] — так одна и та же буква одинаково выглядит
/// на любом экране.
class TracingShape {
  final String id;
  final String label;

  /// Части буквы в том порядке, в котором их рисуют.
  final List<TracingShapePart> parts;

  /// Толщина линии в тех же единицах, что и геометрия частей.
  final double strokeWidth;

  /// Радиус диакритической точки в единицах фигуры.
  final double dotRadius;

  /// Кадр, общий для всех букв набора (viewBox из SVG). Если задан, в холст
  /// вписывается именно он, а не габариты конкретной буквы — иначе ب и ت
  /// окажутся разного размера и на разной высоте, потому что у одной точки
  /// снизу, а у другой сверху.
  final Rect? viewBox;

  TracingShape({
    required this.id,
    required this.label,
    required this.parts,
    required this.strokeWidth,
    double? dotRadius,
    this.viewBox,
  }) : dotRadius = dotRadius ?? strokeWidth * 0.55;

  List<Path> get paths => [for (final part in parts) ...part.paths];

  List<Offset> get dots => [for (final part in parts) ...part.dots];

  Rect? _bounds;

  /// Габариты самой буквы с учётом толщины линии и точек.
  ///
  /// Считаются по точкам кривой, а не через `Path.getBounds()`: тот возвращает
  /// габариты вместе с контрольными точками, а они у безье уходят далеко за
  /// саму линию — у ба контрольная точка вылетает за пределы кадра.
  Rect get bounds => _bounds ??= _computeBounds();

  /// Что именно вписывается в холст: общий кадр, если он задан.
  Rect get frame => viewBox ?? bounds;

  Rect _computeBounds() {
    Rect? result;

    for (final path in paths) {
      for (final metric in path.computeMetrics()) {
        final step = math.max(1.0, metric.length / 128);
        for (var distance = 0.0; distance <= metric.length; distance += step) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent == null) continue;
          final rect = Rect.fromCircle(
            center: tangent.position,
            radius: strokeWidth / 2,
          );
          result = result == null ? rect : result.expandToInclude(rect);
        }
      }
    }

    for (final dot in dots) {
      final rect = Rect.fromCircle(center: dot, radius: dotRadius);
      result = result == null ? rect : result.expandToInclude(rect);
    }

    return result ?? Rect.zero;
  }

  /// Вписывает фигуру в [size] с сохранением пропорций и центрированием.
  ResolvedTracingShape resolve(Size size, {double padding = 24}) {
    final raw = frame;
    final availableWidth = (size.width - padding * 2).clamp(
      1.0,
      double.infinity,
    );
    final availableHeight = (size.height - padding * 2).clamp(
      1.0,
      double.infinity,
    );

    final scale = raw.isEmpty
        ? 1.0
        : (availableWidth / raw.width) < (availableHeight / raw.height)
        ? availableWidth / raw.width
        : availableHeight / raw.height;

    final offset = Offset(
      (size.width - raw.width * scale) / 2 - raw.left * scale,
      (size.height - raw.height * scale) / 2 - raw.top * scale,
    );

    // Column-major матрица 4x4 для Path.transform: только масштаб и сдвиг.
    final storage = Float64List.fromList([
      scale, 0, 0, 0, //
      0, scale, 0, 0, //
      0, 0, 1, 0, //
      offset.dx, offset.dy, 0, 1, //
    ]);

    return ResolvedTracingShape(
      shape: this,
      scale: scale,
      offset: offset,
      parts: [
        for (final part in parts)
          ResolvedTracingPart(
            id: part.id,
            label: part.label,
            paths: [for (final path in part.paths) path.transform(storage)],
            dots: [for (final dot in part.dots) dot * scale + offset],
            strokeWidth: strokeWidth * scale,
            dotRadius: dotRadius * scale,
          ),
      ],
    );
  }
}

/// Часть фигуры, пересчитанная под размер холста.
class ResolvedTracingPart {
  final String id;
  final String label;
  final List<Path> paths;
  final List<Offset> dots;
  final double strokeWidth;
  final double dotRadius;

  ResolvedTracingPart({
    required this.id,
    required this.label,
    required this.paths,
    required this.dots,
    required this.strokeWidth,
    required this.dotRadius,
  });

  List<StrokeSignature>? _signatures;

  /// Форма части без места, размера и пропорций — эталон для сравнения
  /// с тем, что нарисовал человек. Пусто у частей из одних точек.
  ///
  /// Эталонов несколько, потому что одну и ту же часть законно провести
  /// по-разному, а сигнатура сравнивается **по порядку точек**. У части из
  /// двух линий свободны три вещи: с какой начали, в какую сторону вели
  /// каждую и отрывали ли перо на переходе. Порядок точек внутри одного
  /// эталона фиксирован, поэтому каждый способ — свой эталон, и [signatures]
  /// перебирает их все; глобальный разворот перебирать не нужно, его берёт
  /// на себя [StrokeSignature.distanceTo].
  ///
  /// Без этого перебора соединённые формы ـحـ, ـضـ, ـطـ узнавались только
  /// при совпадении с направлением, в котором линии лежат в svg: обычный
  /// росчерк справа налево давал расхождение 0.2–0.5 при пороге 0.08.
  List<StrokeSignature> get signatures => _signatures ??= _buildSignatures();

  List<StrokeSignature> _buildSignatures() {
    final lines = StrokeSignature.polylinesOf(paths);
    if (lines.isEmpty) return const [];

    // Нормировка едина для всех эталонов и для ввода: её выбирает форма
    // части целиком, иначе варианты сравнивались бы по разным правилам.
    final base = StrokeSignature.ofPolylines(lines);
    if (base == null) return const [];
    if (lines.length != 2) return [base];

    final uniform = base.uniform;
    final a = lines[0];
    final b = lines[1];
    final reversedA = a.reversed.toList();
    final reversedB = b.reversed.toList();

    final result = <StrokeSignature>[];
    for (final variant in [
      [a, b],
      [a, reversedB],
      [reversedA, b],
      [b, a],
    ]) {
      // Перо оторвали: перемычки нет.
      final lifted = StrokeSignature.ofPolylines(variant, uniform: uniform);
      if (lifted != null) result.add(lifted);
      // Вели не отрываясь: перемычка нарисована и в форму входит.
      final joined = StrokeSignature.ofPoints([
        for (final line in variant) ...line,
      ], uniform: uniform);
      if (joined != null) result.add(joined);
    }
    return result.isEmpty ? [base] : result;
  }

  Rect? _bounds;

  /// Габариты части по точкам кривой, с учётом толщины линии.
  Rect get bounds => _bounds ??= _computeBounds();

  Rect _computeBounds() {
    Rect? result;

    for (final path in paths) {
      for (final metric in path.computeMetrics()) {
        final step = math.max(1.0, metric.length / 128);
        for (var distance = 0.0; distance <= metric.length; distance += step) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent == null) continue;
          final rect = Rect.fromCircle(
            center: tangent.position,
            radius: strokeWidth / 2,
          );
          result = result == null ? rect : result.expandToInclude(rect);
        }
      }
    }

    for (final dot in dots) {
      final rect = Rect.fromCircle(center: dot, radius: dotRadius);
      result = result == null ? rect : result.expandToInclude(rect);
    }

    return result ?? Rect.zero;
  }

  /// Та же часть, перенесённая и отмасштабированная — например, туда, где
  /// пользователь нарисовал букву по памяти.
  ResolvedTracingPart transformed(double scale, Offset offset) {
    final storage = Float64List.fromList([
      scale, 0, 0, 0, //
      0, scale, 0, 0, //
      0, 0, 1, 0, //
      offset.dx, offset.dy, 0, 1, //
    ]);

    return ResolvedTracingPart(
      id: id,
      label: label,
      paths: [for (final path in paths) path.transform(storage)],
      dots: [for (final dot in dots) dot * scale + offset],
      strokeWidth: strokeWidth * scale,
      dotRadius: dotRadius * scale,
    );
  }

  /// [strokeWidth] перекрывает собственную толщину части — им рисуют тем же
  /// пером, каким пользователь ведёт линию. Радиус точки меняется в той же
  /// пропорции, иначе точка «потолстеет» относительно линии.
  void paint(Canvas canvas, Color color, {double? strokeWidth}) {
    final width = strokeWidth ?? this.strokeWidth;
    final ratio = this.strokeWidth == 0 ? 1.0 : width / this.strokeWidth;

    final stroke = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final path in paths) {
      canvas.drawPath(path, stroke);
    }

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final dot in dots) {
      canvas.drawCircle(dot, dotRadius * ratio, fill);
    }
  }
}

/// Фигура, пересчитанная под конкретный размер холста — в координатах,
/// в которых приходят точки пальца.
class ResolvedTracingShape {
  final TracingShape shape;

  /// Масштаб и сдвиг, которыми фигура вписана в холст.
  final double scale;
  final Offset offset;

  final List<ResolvedTracingPart> parts;

  ResolvedTracingShape({
    required this.shape,
    required this.scale,
    required this.offset,
    required this.parts,
  });

  /// Кадр фигуры в координатах холста.
  Rect get frame => Rect.fromLTWH(
    shape.frame.left * scale + offset.dx,
    shape.frame.top * scale + offset.dy,
    shape.frame.width * scale,
    shape.frame.height * scale,
  );

  List<Path> get paths => [for (final part in parts) ...part.paths];

  List<Offset> get dots => [for (final part in parts) ...part.dots];

  double get strokeWidth => parts.isEmpty ? 0 : parts.first.strokeWidth;

  double get dotRadius => parts.isEmpty ? 0 : parts.first.dotRadius;

  ResolvedTracingPart? _whole;

  /// Вся фигура как одна часть — для проверки целиком.
  ResolvedTracingPart get whole => _whole ??= ResolvedTracingPart(
    id: shape.id,
    label: shape.label,
    paths: paths,
    dots: dots,
    strokeWidth: strokeWidth,
    dotRadius: dotRadius,
  );

  /// Вся фигура, перенесённая на новое место: масштаб и сдвиг применяются
  /// поверх уже вычисленных.
  ResolvedTracingShape transformed(double extraScale, Offset extraOffset) =>
      ResolvedTracingShape(
        shape: shape,
        scale: scale * extraScale,
        offset: offset * extraScale + extraOffset,
        parts: [
          for (final part in parts) part.transformed(extraScale, extraOffset),
        ],
      );

  /// Точка холста → координаты фигуры. Пригодится, когда будем считать,
  /// насколько ввод пользователя покрывает букву.
  Offset toShapeSpace(Offset canvasPoint) => (canvasPoint - offset) / scale;

  /// Координаты фигуры → точка холста.
  Offset toCanvasSpace(Offset shapePoint) => shapePoint * scale + offset;

  void paint(Canvas canvas, Color color, {double? strokeWidth}) {
    for (final part in parts) {
      part.paint(canvas, color, strokeWidth: strokeWidth);
    }
  }
}

/// Прогресс пошагового рисования: сколько частей фигуры уже собрано.
class TracingProgress {
  final int completed;
  final int total;

  /// Название части, которую предстоит нарисовать.
  final String? nextLabel;

  const TracingProgress({
    required this.completed,
    required this.total,
    this.nextLabel,
  });

  bool get isComplete => total > 0 && completed >= total;

  @override
  String toString() => 'TracingProgress($completed/$total, next: $nextLabel)';
}

/// Готовые фигуры для обводки.
class TracingShapes {
  TracingShapes._();

  /// Арабская буква «ба» (ب) — чаша с точкой снизу.
  static TracingShape get arabicBa => TracingShape(
    id: 'ba',
    label: 'ب',
    strokeWidth: 112,
    parts: [
      TracingShapePart(
        id: 'base',
        label: 'основа',
        paths: [
          Path()
            ..moveTo(232, 200)
            ..cubicTo(212, 450, 320, 505, 500, 505)
            ..cubicTo(700, 505, 792, 450, 772, 205),
        ],
      ),
      const TracingShapePart(
        id: 'dot',
        label: 'точка',
        dots: [Offset(507, 700)],
      ),
    ],
  );
}
