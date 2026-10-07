import 'dart:convert';
import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/explanation_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/explanation_document.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Регрессия: при пересборке курса объяснения и слова-примеры должны
/// оставаться в YAML, а все ссылки из JSON должны вести к валидным карточкам.
void main() {
  final stages = [
    for (final asset in CurriculumLoader.defaultAssets)
      jsonDecode(File(asset).readAsStringSync()) as Map<String, dynamic>,
  ];
  final atoms = CurriculumLoader.merge([
    for (final stage in stages) CurriculumLoader.parse(jsonEncode(stage)),
  ]).nodes.map((node) => node.atom).toList();
  final byId = {for (final atom in atoms) atom.id: atom};

  ExplanationContent load(String path) =>
      ExplanationLoader.parse(File(path).readAsStringSync(), sourceName: path);

  test('каждый атом курса имеет отдельную валидную YAML-карточку', () {
    for (final stage in stages) {
      for (final node in stage['nodes'] as List<dynamic>? ?? const []) {
        final raw =
            (node as Map<String, dynamic>)['atom'] as Map<String, dynamic>;
        expect(raw, isNot(contains('note')), reason: raw['id'] as String);
        expect(raw, isNot(contains('example')), reason: raw['id'] as String);
        expect(raw['explanationAsset'], isNotNull, reason: raw['id'] as String);
      }
    }
    for (final atom in atoms) {
      final path = atom.explanationAsset!;
      expect(File(path).existsSync(), isTrue, reason: atom.id);
      final card = load(path);
      expect(card.document.blocks, isNotEmpty, reason: atom.id);
    }
  });

  test('слова в карточках соединённых форм подсвечивают нужную букву', () {
    final connectors = {
      for (final a in atoms.where((a) => a.form == LetterForm.initial))
        byId['${a.letterId}.isolated']!.display,
    };
    for (final atom in atoms.where(
      (a) => a.kind == AtomKind.letterForm && a.form != LetterForm.isolated,
    )) {
      final card = load(atom.explanationAsset!);
      final word = card.document.blocks
          .whereType<ExplanationWord>()
          .single
          .word;
      final isolated = byId['${atom.letterId}.isolated']!;
      expect(word.text[word.highlight], isolated.display, reason: atom.id);
      if (atom.form == LetterForm.finalForm || atom.form == LetterForm.medial) {
        expect(
          word.highlight > 0 &&
              connectors.contains(word.text[word.highlight - 1]),
          isTrue,
          reason: atom.id,
        );
      }
      if (atom.form == LetterForm.initial || atom.form == LetterForm.medial) {
        expect(word.highlight, lessThan(word.text.length - 1), reason: atom.id);
      }
    }
  });

  test('у каждой буквы есть обзор форм со словами из её карточек', () {
    for (final isolated in atoms.where((a) => a.form == LetterForm.isolated)) {
      final path = isolated.formsOverviewAsset;
      expect(path, isNotNull, reason: isolated.id);
      final forms = load(
        path!,
      ).document.blocks.whereType<ExplanationForms>().single.forms;
      final letterAtoms = atoms.where(
        (a) => a.letterId == isolated.letterId && a.form != null,
      );
      expect(forms.length, letterAtoms.length, reason: isolated.id);
      for (final form in forms) {
        final atom = letterAtoms.firstWhereOrNull(
          (a) => a.form == form.position,
        );
        expect(atom, isNotNull, reason: isolated.id);
        expect(form.glyph, atom!.display);
        if (form.position != LetterForm.isolated) {
          final word = load(
            atom.explanationAsset!,
          ).document.blocks.whereType<ExplanationWord>().single.word;
          expect(form.example?.text, word.text);
          expect(form.example?.highlight, word.highlight);
        }
      }
    }
  });
}
