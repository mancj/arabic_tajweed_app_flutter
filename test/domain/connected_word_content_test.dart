// Фиксированный банк ограничивает объём будущей озвучки: генератор не должен
// создавать новые звучащие сочетания или вводить недоступные слоги.
// Пропуски в разных позициях используют ID и запись того же целого слова.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/connected_word_content.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final introduced = curriculum.nodes.map((node) => node.atom).toList();
  final atoms = [
    ...introduced,
    for (final letter in curriculum.baseLetters)
      ...HarakaSyllables.completeFamily(letter, introduced),
  ];
  final introduction = curriculum.wordsForSet('harakaIntroduction');

  test('дострой выбирает только слова банка, с общими ID и аудио', () {
    final content = ConnectedWordContent(
      atoms,
      words: introduction,
      random: Random(11),
    );
    final words = {
      for (final word in content.availableWords) word.contentId: word,
    };
    for (var attempt = 0; attempt < 100; attempt++) {
      final connection = content.randomConnection!;
      final word = words[connection.contentId]!;
      expect(connection.display, word.display);
      expect(connection.audioAsset, word.audioAsset);
      expect(
        connection.expectedFormId,
        word.steps[connection.missingIndex].expectedFormId,
      );
    }
  });

  test('доступные случайные слоги не заменяют недоступный пример банка', () {
    final content = ConnectedWordContent([
      for (final atom in atoms)
        if (!atom.id.startsWith('vowel.') ||
            {'vowel.ta.kasra', 'vowel.dal.damma'}.contains(atom.id))
          atom,
    ], words: introduction);
    expect(content.availableWords, isEmpty);
    expect(content.randomConnection, isNull);
  });

  test('записанное аудио целого слова сохраняется при любом пропуске', () {
    final example = introduction.first.copyWith(recorded: true);
    final content = ConnectedWordContent(atoms, words: [example]);
    final word = content.word(example)!;
    for (var index = 0; index < word.steps.length; index++) {
      final connection = content.connection(word, missingIndex: index);
      expect(connection.contentId, example.id);
      expect(connection.audioAsset, example.audioFile);
    }
  });

  test('весь банк собирается без потери букв и огласовок', () {
    final content = ConnectedWordContent(atoms, words: curriculum.words);
    final questions = content.availableWords;
    expect(
      questions.map((word) => word.contentId),
      unorderedEquals(curriculum.words.map((word) => word.id)),
    );
    for (final question in questions) {
      final glyphs = question.preview(
        question.steps.map((step) => step.expectedFormId).toList(),
        question.steps.map((step) => step.expectedMarkId).toList(),
      );
      expect(
        glyphs.join().replaceAll('\u200d', ''),
        question.display,
        reason: question.contentId,
      );
      for (final step in question.steps) {
        expect(
          step.formOptions.map((atom) => atom.id),
          contains(step.expectedFormId),
        );
      }
    }
  });

  test('форма зависит от соседних соединений, включая разрыв внутри слова', () {
    final content = ConnectedWordContent(atoms, words: curriculum.words);
    for (final (id, forms) in [
      (
        'ta_a_ra_a_kaf_a',
        [LetterForm.initial, LetterForm.finalForm, LetterForm.isolated],
      ),
      (
        'dal_a_kha_a_lam_a',
        [LetterForm.isolated, LetterForm.initial, LetterForm.finalForm],
      ),
      (
        'waw_u_dod_i_ayn_a',
        [LetterForm.isolated, LetterForm.initial, LetterForm.finalForm],
      ),
      (
        'kha_a_lam_a_qof_a_ha_u',
        [
          LetterForm.initial,
          LetterForm.medial,
          LetterForm.medial,
          LetterForm.finalForm,
        ],
      ),
    ]) {
      final word = curriculum.words.firstWhere((word) => word.id == id);
      final question = content.word(word)!;
      expect(
        question.steps.map((step) => step.part.form.form),
        forms,
        reason: id,
      );
      for (final (index, step) in question.steps.indexed) {
        final connection = content.connection(question, missingIndex: index);
        expect(
          connection
              .evaluate(
                formId: step.expectedFormId,
                markId: step.expectedMarkId,
              )
              .correct,
          isTrue,
        );
        expect(connection.audioAsset, question.audioAsset);
      }
    }
  });
}
