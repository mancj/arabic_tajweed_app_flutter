import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

/// Курикулум и папка с осевыми SVG собираются порознь — генератором и
/// в Фигме, — и разъезжаются молча: атом без фигуры просто перестаёт
/// спрашиваться обводкой, а лишний файл никто не открывает. Держим их
/// сверенными: один файл на форму, ни одного лишнего.
void main() {
  const dir = 'assets/svg/alphabet';

  test('у каждой формы буквы есть свой SVG, и наоборот', () {
    final atoms = [
      for (final asset in CurriculumLoader.defaultStageAssets)
        ...CurriculumLoader.parse(
          File(asset).readAsStringSync(),
        ).nodes.map((node) => node.atom),
    ];

    final letterForms = atoms.where((a) => a.kind == AtomKind.letterForm);
    final tracings = <String>{};
    for (final atom in letterForms) {
      final tracing = atom.tracing;
      expect(tracing, isNotNull, reason: 'у ${atom.id} нет поля tracing');
      expect(
        File('$dir/$tracing.svg').existsSync(),
        isTrue,
        reason: '${atom.id} ссылается на $tracing.svg, которого нет',
      );
      tracings.add(tracing!);
    }

    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.svg'))
        .map((name) => name.substring(0, name.length - 4))
        .toSet();

    expect(
      files.difference(tracings),
      isEmpty,
      reason: 'эти SVG есть, но курикулум их не спрашивает',
    );
  });
}
