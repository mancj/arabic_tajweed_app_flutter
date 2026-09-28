// Защищает полный набор записей огласовок: отсутствующий MP3 плеер проглотит
// молча, и упражнение «звук → написание» станет невозможно выполнить.
// При добавлении записей и пересборке курса ссылки в JSON и YAML не должны
// оставаться на TTS: иначе готовая запись есть, но пользователь её не слышит.
import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/explanation_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/explanation_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final alphabet =
      CurriculumLoader.parse(
            File('assets/curriculum/stage1.json').readAsStringSync(),
          ).nodes
          .map((node) => node.atom)
          .where((atom) => atom.form == LetterForm.isolated)
          .toList();
  final vowels = {'fatha': 'َ', 'kasra': 'ِ', 'damma': 'ُ'};
  final recordings = {
    for (final letter in alphabet)
      for (final vowel in vowels.entries)
        '${letter.letterId == 'alif' ? (vowel.key == 'kasra' ? 'إ' : 'أ') : letter.display}${vowel.value}':
            'audio/harakat/${letter.letterId}_${vowel.key}.mp3',
  };

  test('у всех 28 букв есть фатха, касра и дамма', () {
    final letterIds = alphabet
        .map((atom) => atom.letterId)
        .whereType<String>()
        .toSet();
    final expected = {
      for (final letterId in letterIds)
        for (final vowel in ['fatha', 'kasra', 'damma'])
          '${letterId}_$vowel.mp3',
    };
    final actual = Directory('assets/audio/harakat')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.mp3'))
        .toSet();

    expect(letterIds, hasLength(28));
    // Дополнительные записи, например отдельная хамза, допустимы.
    expect(actual, containsAll(expected));
    expect(
      actual.every(
        (name) => File('assets/audio/harakat/$name').lengthSync() > 0,
      ),
      isTrue,
    );
  });

  test('задания на краткие слоги используют записанные MP3', () {
    final stage = CurriculumLoader.parse(
      File('assets/curriculum/stage3.json').readAsStringSync(),
    );
    for (final atom
        in stage.nodes
            .map((node) => node.atom)
            .where(
              (atom) =>
                  atom.kind == AtomKind.haraka ||
                  atom.kind == AtomKind.syllable,
            )) {
      expect(recordings, contains(atom.display), reason: atom.id);
      expect(atom.audioAsset, recordings[atom.display], reason: atom.id);
    }
  });

  test('карточки используют записи кратких слогов вместо TTS', () {
    final cards = Directory(
      'assets/explanations/ru',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.yaml'));
    for (final file in cards) {
      final content = ExplanationLoader.parse(
        file.readAsStringSync(),
        sourceName: file.path,
      );
      for (final block in content.document.blocks) {
        final glyphs = switch (block) {
          ExplanationLetter(:final letter) => [letter],
          ExplanationExamples(:final examples) => examples,
          _ => const <ExplanationGlyph>[],
        };
        for (final glyph in glyphs) {
          final recording = recordings[glyph.glyph];
          if (recording == null || glyph.audio == null) continue;
          expect(
            glyph.audio,
            recording,
            reason: '${file.path}: ${glyph.glyph}',
          );
        }
      }
    }
  });
}
