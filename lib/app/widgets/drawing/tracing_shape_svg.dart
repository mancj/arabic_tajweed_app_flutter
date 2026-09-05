import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';

import 'tracing_shape.dart';

/// Читает букву из SVG, нарисованного осевыми линиями.
///
/// Ожидания к файлу:
/// * `fill="none"` и настоящий `stroke` — то есть `d` это траектория пера,
///   а не контур вокруг буквы (после Outline Stroke файл не годится);
/// * общий `viewBox` на весь набор букв, с единой базовой линией;
/// * каждая часть — отдельный элемент, порядок задаётся атрибутом `id`
///   вида `1-base`, `2-dot`; без него порядок восстанавливается по смыслу
///   (сначала линии, потом точки);
/// * пути разомкнуты и идут в направлении письма, справа налево.
class TracingShapeSvg {
  TracingShapeSvg._();

  /// Точку рисуют коротким отрезком с круглым концом: на экране это круг.
  /// Всё, что короче толщины пера, считаем точкой, а не линией.
  static const _dotLengthFactor = 1.0;

  static Future<TracingShape> load(
    String assetPath, {
    String? id,
    String? label,
  }) async {
    final source = await rootBundle.loadString(assetPath);
    return parse(
      source,
      id: id ?? assetPath.split('/').last.replaceAll('.svg', ''),
      label: label,
    );
  }

  static TracingShape parse(
    String source, {
    required String id,
    String? label,
  }) {
    final document = XmlDocument.parse(source);
    final svg = document.findAllElements('svg').first;

    final elements = svg.descendantElements
        .where((e) => const {'path', 'circle', 'line'}.contains(e.localName))
        .toList();

    if (elements.isEmpty) {
      throw FormatException('В SVG "$id" нет ни одного path, circle или line');
    }

    final strokeWidth = _firstStrokeWidth(elements);
    final entries = [
      for (var i = 0; i < elements.length; i++)
        _entryOf(elements[i], i, strokeWidth),
    ];

    return TracingShape(
      id: id,
      label: label ?? id,
      strokeWidth: strokeWidth,
      dotRadius: strokeWidth / 2,
      viewBox: _viewBoxOf(svg),
      parts: _partsOf(entries),
    );
  }

  static double _firstStrokeWidth(List<XmlElement> elements) {
    for (final element in elements) {
      final raw = element.getAttribute('stroke-width');
      final value = raw == null ? null : double.tryParse(raw);
      if (value != null && value > 0) return value;
    }
    return 20;
  }

  static Rect? _viewBoxOf(XmlElement svg) {
    final raw = svg.getAttribute('viewBox');
    if (raw == null) return null;

    final parts = raw.trim().split(RegExp(r'[\s,]+'));
    if (parts.length != 4) return null;

    final values = [for (final part in parts) double.tryParse(part)];
    if (values.any((v) => v == null)) return null;

    return Rect.fromLTWH(values[0]!, values[1]!, values[2]!, values[3]!);
  }

  static _Entry _entryOf(XmlElement element, int index, double strokeWidth) {
    final id = element.getAttribute('id');
    final order = _orderOf(id) ?? index;

    switch (element.localName) {
      case 'circle':
        final center = Offset(_number(element, 'cx'), _number(element, 'cy'));
        return _Entry(order: order, index: index, role: id, dot: center);

      case 'line':
        final from = Offset(_number(element, 'x1'), _number(element, 'y1'));
        final to = Offset(_number(element, 'x2'), _number(element, 'y2'));
        return _Entry(
          order: order,
          index: index,
          role: id,
          path: Path()
            ..moveTo(from.dx, from.dy)
            ..lineTo(to.dx, to.dy),
        );

      default:
        final data = element.getAttribute('d');
        if (data == null || data.isEmpty) {
          throw FormatException(
            'У элемента ${element.localName} нет атрибута d',
          );
        }

        final path = parseSvgPathData(data);
        final dot = _asDot(path, strokeWidth);
        return dot == null
            ? _Entry(order: order, index: index, role: id, path: path)
            : _Entry(order: order, index: index, role: id, dot: dot);
    }
  }

  /// Путь короче пера — это нарисованная точка. Возвращает её центр.
  static Offset? _asDot(Path path, double strokeWidth) {
    final metrics = path.computeMetrics().toList();
    if (metrics.length != 1) return null;

    final metric = metrics.first;
    if (metric.length > strokeWidth * _dotLengthFactor) return null;

    return metric.getTangentForOffset(metric.length / 2)?.position;
  }

  /// Числовой префикс id: «2-dot» → 2. Так задаётся порядок написания.
  static int? _orderOf(String? id) {
    if (id == null) return null;
    final match = RegExp(r'^(\d+)').firstMatch(id);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static double _number(XmlElement element, String name) =>
      double.tryParse(element.getAttribute(name) ?? '') ?? 0;

  /// Собирает части в порядке написания.
  ///
  /// Если у элементов есть числовые id — порядок берётся из них. Внутри
  /// одного номера и вообще без номеров линии идут раньше точек: скелет
  /// буквы пишут целиком, точки ставят после. Редакторы кладут их в файл
  /// в обратном порядке, а фигме одного номера на линию и точку хватает.
  static List<TracingShapePart> _partsOf(List<_Entry> entries) {
    final tagged = entries.any((entry) => _orderOf(entry.role) != null);

    final sorted = [...entries]..sort((a, b) {
      if (tagged && a.order != b.order) return a.order.compareTo(b.order);
      if (a.isDot != b.isDot) return a.isDot ? 1 : -1;
      return a.index.compareTo(b.index);
    });

    final parts = <TracingShapePart>[];
    for (final entry in sorted) {
      final role = _roleOf(entry);
      final last = parts.isEmpty ? null : parts.last;

      // Соседние однородные элементы — одна часть: две точки над ت ставят
      // подряд, и ждать их надо вместе.
      if (last != null && last.id == role) {
        parts[parts.length - 1] = TracingShapePart(
          id: role,
          label: last.label,
          paths: [...last.paths, if (entry.path != null) entry.path!],
          dots: [...last.dots, if (entry.dot != null) entry.dot!],
        );
        continue;
      }

      parts.add(
        TracingShapePart(
          id: role,
          label: entry.isDot ? 'точка' : 'основа',
          paths: [if (entry.path != null) entry.path!],
          dots: [if (entry.dot != null) entry.dot!],
        ),
      );
    }

    return parts;
  }

  /// Роль без номера порядка и без суффикса-дубля: фигма не даёт двум
  /// слоям одно имя и второй «1-dot» экспортирует как «1-dot_2», хотя это
  /// та же точка и ждать их надо вместе.
  static String _roleOf(_Entry entry) {
    final role = entry.role
        ?.replaceFirst(RegExp(r'^\d+[-_]?'), '')
        .replaceFirst(RegExp(r'_\d+$'), '');
    if (role != null && role.isNotEmpty) return role;
    return entry.isDot ? 'dot' : 'base';
  }
}

class _Entry {
  final int order;

  /// Место в файле. Разводит элементы, у которых совпали и номер, и роль.
  final int index;
  final String? role;
  final Path? path;
  final Offset? dot;

  _Entry({
    required this.order,
    required this.index,
    this.role,
    this.path,
    this.dot,
  });

  bool get isDot => dot != null;
}
