// Защищает загрузку программы: первые буквы должны быть доступны на старте,
// их объяснения не должны теряться, а формы ждут знакомства с отдельной буквой.
// При смене формата JSON граф должен сохраняться после чтения и записи.
import 'dart:convert';
import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  CurriculumContext ctxWith(Map<String, AtomState> states) => CurriculumContext(
    progress: {
      for (final e in states.entries) e.key: AtomProgress(state: e.value),
    },
    formsByLetter: const {},
  );

  test('первый урок знакомит со всем набором ا ب ت ث', () {
    final available = curriculum.availableAtoms(ctxWith({}));
    expect(available.map((a) => a.id), [
      'concept.letter',
      'concept.makhraj',
      'alif.isolated',
      'ba.isolated',
      'ta.isolated',
      'tha.isolated',
    ]);
  });

  test('у каждой буквы первого урока есть объяснение', () {
    final first = curriculum.nodes
        .where((n) => n.requirement is Always)
        .map((n) => n.atom);
    expect(first.every((a) => a.explanationAsset != null), isTrue);
  });

  test('у алифа только две формы — он не соединяется слева', () {
    final alifForms = curriculum.nodes
        .where((n) => n.atom.letterId == 'alif')
        .toList();
    expect(alifForms, hasLength(2));
  });

  test('формы открываются цепочкой, а не все сразу', () {
    final ctx = ctxWith({
      'concept.letter': AtomState.known,
      'alif.isolated': AtomState.known,
      'concept.dots': AtomState.known,
    });
    final ids = curriculum.availableAtoms(ctx).map((a) => a.id);
    expect(ids, contains('ba.isolated'));
    expect(ids, isNot(contains('ba.finalForm')));
  });

  test('вторая форма буквы ждёт знакомства с первой', () {
    // Раньше порог был по освоенности, и второй урок оказывался открыт,
    // но вводить в нём было нечего: цепочка форм оставалась запертой.
    expect(
      curriculum.availableAtoms(ctxWith({})).map((a) => a.id),
      isNot(contains('ba.finalForm')),
    );

    final introduced = ctxWith({'ba.isolated': AtomState.introduced});
    expect(
      curriculum.availableAtoms(introduced).map((a) => a.id),
      contains('ba.finalForm'),
    );
  });

  test('граф переживает круг сериализации', () {
    final again = CurriculumLoader.parse(jsonEncode(curriculum.toJson()));
    expect(
      again.nodes.map((n) => n.atom.id),
      curriculum.nodes.map((n) => n.atom.id),
    );
  });
}
