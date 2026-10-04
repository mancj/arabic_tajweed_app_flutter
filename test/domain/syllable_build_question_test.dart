// Будущая общая проверка не должна скрыть, какая из двух частей ошибочна.
// Сборка хамзы с касрой обязана менять أ на إ, а генератор не должен
// предлагать сочетания, которых нет в переданном учебном пуле.
import 'dart:math';

import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/syllable_build_question.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haraka_test_content.dart';

void main() {
  final question = SyllableBuildQuestion(
    prompt: harakaTestAtom('ra', 'kasra'),
    letterOptions: [
      harakaTestAtom('ra', 'kasra'),
      harakaTestAtom('ba', 'fatha'),
      harakaTestAtom('kaf', 'fatha'),
    ],
  );

  for (final (letter, mark, letterCorrect, harakaCorrect) in [
    ('ra', 'kasra', true, true),
    ('ra', 'fatha', true, false),
    ('ba', 'kasra', false, true),
    ('ba', 'fatha', false, false),
  ]) {
    test('две части оцениваются независимо: $letter / $mark', () {
      final result = question.evaluate(
        letterId: letter,
        markId: 'haraka.$mark',
      );
      expect(result.letterCorrect, letterCorrect);
      expect(result.harakaCorrect, harakaCorrect);
      expect(result.correct, letterCorrect && harakaCorrect);
    });
  }

  test(
    'черновик содержит только выбранные части, неизвестные части отвергаются',
    () {
      expect(question.preview(null, null), isNull);
      expect(question.preview('ra', null), 'ر');
      expect(question.preview('ra', 'haraka.kasra'), 'رِ');
      expect(question.preview('ba', 'haraka.kasra'), 'بِ');
      expect(question.preview('unknown', 'haraka.kasra'), isNull);
      expect(question.preview('ra', 'haraka.unknown'), isNull);
    },
  );

  final alif = HarakaSyllables.completeFamily(
    const Atom(
      id: 'alif.isolated',
      kind: AtomKind.letterForm,
      letterId: 'alif',
      display: 'ا',
    ),
    const [],
  );
  test('касра перемещает хамзу вниз, фатха возвращает наверх', () {
    final question = SyllableBuildQuestion(
      prompt: alif[1],
      letterOptions: [
        alif[0],
        harakaTestAtom('ra', 'fatha'),
        harakaTestAtom('ba', 'fatha'),
      ],
    );
    expect(question.preview('alif', null), 'أ');
    expect(question.preview('alif', 'haraka.kasra'), 'إِ');
    expect(question.preview('alif', 'haraka.fatha'), 'أَ');
    expect(question.preview('alif', 'haraka.damma'), 'أُ');
  });

  test(
    'любая сборка из вариантов уже есть в пуле, неполная буква исключена',
    () {
      final pool = [...harakaTestSyllables, alif[0]];
      final random = Random(16);
      final seenMarks = <String>{};
      for (var i = 0; i < 40; i++) {
        final question = SyllableBuildQuestion.generate(pool, random: random);
        seenMarks.add(question.expectedMarkId);
        expect(pool, contains(question.prompt));
        expect(
          question.letterOptions.map((atom) => atom.letterId).toSet(),
          hasLength(3),
        );
        expect(
          question.letterOptions.map((atom) => atom.letterId),
          contains(question.prompt.letterId),
        );
        expect(
          question.letterOptions.map((atom) => atom.letterId),
          isNot(contains('alif')),
        );
        for (final option in question.letterOptions) {
          for (final mark in HarakaSyllables.marks) {
            expect(
              pool.map((atom) => atom.display),
              contains(question.preview(option.letterId, mark.id)),
            );
          }
        }
      }
      expect(seenMarks, {'haraka.fatha', 'haraka.kasra', 'haraka.damma'});
    },
  );

  test('недостаточный пул не дополняется новыми буквами', () {
    expect(
      () => SyllableBuildQuestion.generate(
        harakaTestSyllables.where((atom) => atom.letterId == 'ra').toList(),
      ),
      throwsArgumentError,
    );
  });
}
