import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Соединённая форма показывается в слове-примере с подсветкой буквы.
/// Слово и индекс задаются в контенте руками, поэтому сверяем: пример
/// есть у каждой такой формы, и по индексу стоит именно эта буква.
void main() {
  final atoms = [
    for (final asset in CurriculumLoader.defaultStageAssets)
      ...CurriculumLoader.parse(
        File(asset).readAsStringSync(),
      ).nodes.map((node) => node.atom),
  ];

  test('у каждой соединённой формы есть слово, и буква стоит по индексу', () {
    final joined = atoms.where(
      (a) => a.kind == AtomKind.letterForm && a.form != LetterForm.isolated,
    );
    expect(joined, isNotEmpty);

    for (final atom in joined) {
      final example = atom.example;
      expect(example, isNotNull, reason: 'у ${atom.id} нет слова-примера');

      final isolated = atoms.firstWhereOrNull(
        (a) => a.id == '${atom.letterId}.isolated',
      );
      expect(isolated, isNotNull, reason: 'у ${atom.id} нет изолированной');
      expect(
        example!.word[example.index],
        isolated!.display,
        reason: '${atom.id}: в ${example.word}[${example.index}] не та буква',
      );
    }
  });

  test('в слове буква действительно стоит в показываемой форме', () {
    // Соединяется влево та буква, у которой есть начальная форма.
    final connectors = {
      for (final a in atoms)
        if (a.form == LetterForm.initial)
          atoms.firstWhere((b) => b.id == '${a.letterId}.isolated').display,
    };

    for (final atom in atoms.where((a) => a.example != null)) {
      final WordExample(:word, :index) = atom.example!;
      if (atom.form == LetterForm.finalForm || atom.form == LetterForm.medial) {
        expect(
          index > 0 && connectors.contains(word[index - 1]),
          isTrue,
          reason:
              '${atom.id}: в $word буква не соединена справа, '
              'после ا د ذ ر ز و она рисуется отдельной',
        );
      }
      if (atom.form == LetterForm.initial || atom.form == LetterForm.medial) {
        expect(
          index,
          lessThan(word.length - 1),
          reason: '${atom.id}: в $word буква последняя',
        );
      }
    }
  });

  test('у изолированных форм слова-примера нет', () {
    final isolated = atoms.where((a) => a.form == LetterForm.isolated);
    expect(isolated.map((a) => a.example).nonNulls, isEmpty);
  });
}
