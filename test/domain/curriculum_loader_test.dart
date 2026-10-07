// Защищает загрузку программы: первые буквы должны быть доступны на старте,
// их объяснения не должны теряться, а формы ждут знакомства с отдельной буквой.
// При смене формата JSON граф должен сохраняться после чтения и записи.
// Слова берутся из общего ассета: правка записи должна одновременно менять
// курс и сборки; неизвестная ссылка не должна превращаться в пустое задание.
import 'dart:convert';
import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('загрузчик подключает банк и разрешает ссылки слов курса', () async {
    final loaded = await const CurriculumLoader().load();
    final words = loaded.wordsForSet('wordReading');
    expect(words, isNotEmpty);
    for (final word in words) {
      final atom = loaded.nodes
          .singleWhere((node) => node.atom.id == word.atomId)
          .atom;
      expect(atom.wordId, word.id);
      expect(atom.display, word.display);
      expect(atom.audioAsset, word.audioAsset);
    }
  });

  test('правка записи в JSON обновляет курс и общую подборку', () {
    final bank =
        jsonDecode(File(CurriculumLoader.wordBankAsset).readAsStringSync())
            as Map<String, dynamic>;
    final wordId = (bank['wordSets']['wordReading'] as List).first;
    final words = bank['words'] as List;
    final edited =
        words.singleWhere((word) => word['id'] == wordId)
            as Map<String, dynamic>;
    edited['recorded'] = false;
    bank['wordSets']['harakaIntroduction'] = [wordId];
    final loaded = CurriculumLoader.merge([
      for (final asset in CurriculumLoader.defaultAssets.where(
        (asset) => asset != CurriculumLoader.wordBankAsset,
      ))
        CurriculumLoader.parse(File(asset).readAsStringSync()),
      CurriculumLoader.parse(jsonEncode(bank)),
    ]);
    final selected = loaded.wordsForSet('harakaIntroduction').single;
    expect(selected.id, wordId);
    expect(selected.audioAsset, 'tts:${selected.display}');
    expect(
      loaded.nodes
          .singleWhere((node) => node.atom.wordId == wordId)
          .atom
          .audioAsset,
      selected.audioAsset,
    );
  });

  test('неизвестные слова в подборке и графе отвергаются при загрузке', () {
    final bank = CurriculumLoader.parse(
      File(CurriculumLoader.wordBankAsset).readAsStringSync(),
    );
    expect(
      () => CurriculumLoader.merge([
        bank,
        const Curriculum(
          wordSets: {
            'missing': ['unknown'],
          },
        ),
      ]),
      throwsStateError,
    );
    final wordStage = CurriculumLoader.parse(
      File('assets/curriculum/stage3.json').readAsStringSync(),
    );
    expect(() => CurriculumLoader.merge([wordStage]), throwsStateError);
    expect(() => CurriculumLoader.merge([bank, bank]), throwsStateError);
  });
}
