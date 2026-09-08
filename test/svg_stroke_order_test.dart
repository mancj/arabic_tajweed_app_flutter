import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

/// Порядок частей в SVG задаёт порядок написания, и холст спрашивает их
/// строго по очереди. Перепутанный порядок не выглядит ошибкой в Фигме,
/// а букву ломает наглухо: холст ждёт точку, человек ведёт основу — и так
/// до бесконечности. У nun_end это уже случалось дважды после переэкспорта.
void main() {
  const dir = 'assets/svg/alphabet';

  List<String> idsOf(String source) => [
    for (final match in RegExp(r'<path[^>]*>').allMatches(source))
      RegExp(r'id="([^"]*)"').firstMatch(match.group(0)!)?.group(1) ?? '',
  ];

  int? orderOf(String id) {
    final match = RegExp(r'^(\d+)').firstMatch(id);
    return match == null ? null : int.parse(match.group(1)!);
  }

  String roleOf(String id) => id.replaceFirst(RegExp(r'^\d+[-_]?'), '');

  final files =
      Directory(dir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('у каждой линии есть номер, и нумерация сплошная', () {
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final ids = idsOf(file.readAsStringSync());
      final orders = [for (final id in ids) orderOf(id)];

      expect(orders, isNot(contains(null)), reason: '$name: линия без номера');
      expect(
        orders.nonNulls.toList()..sort(),
        List.generate(ids.length, (i) => i + 1),
        reason: '$name: номера с дырами или повторами — $ids',
      );
    }
  });

  test('точки ставят после линий', () {
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final ids = idsOf(file.readAsStringSync())
        ..sort((a, b) => (orderOf(a) ?? 0).compareTo(orderOf(b) ?? 0));
      final roles = [for (final id in ids) roleOf(id)];
      if (!roles.contains('dot')) continue;

      final lastLine = roles.lastIndexWhere((role) => role != 'dot');
      final firstDot = roles.indexOf('dot');
      expect(
        firstDot,
        greaterThan(lastLine),
        reason: '$name: точка написана раньше линии — $ids',
      );
    }
  });

  /// Имя слоя должно стоять на своей линии. В Фигме имена легко уезжают
  /// на соседние слои: у nun_end «2-dot» оказалось на длинной основе,
  /// а «1-base» — на четырёхпиксельной точке. Порядок номеров при этом
  /// выглядел правильным, а буква не собиралась.
  test('имя слоя совпадает с тем, что нарисовано', () {
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final shape = TracingShapeSvg.parse(file.readAsStringSync(), id: name);

      for (final part in shape.parts) {
        if (part.id == 'dot') {
          expect(
            part.paths,
            isEmpty,
            reason: '$name: слой назван точкой, а нарисована линия',
          );
        }
        if (part.id == 'base') {
          expect(
            part.dots,
            isEmpty,
            reason: '$name: слой назван основой, а нарисована точка',
          );
        }
      }

      final dots = shape.parts.indexWhere((part) => part.dots.isNotEmpty);
      final lines = shape.parts.lastIndexWhere((part) => part.paths.isNotEmpty);
      if (dots < 0) continue;

      expect(
        dots,
        greaterThan(lines),
        reason:
            '$name: точка стала первой частью — холст ждёт её раньше основы',
      );
    }
  });
}
