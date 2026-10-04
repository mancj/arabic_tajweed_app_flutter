// Проверка должна принимать полный набор, а не любой один верный ответ.
// Генератор не должен раскрывать число ответов постоянным количеством или
// подмешивать незнакомые слоги; та же согласная с другим знаком — ловушка.
import 'dart:math';

import 'package:arabic_tajweed_app/domain/haraka_match_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haraka_test_content.dart';

void main() {
  test('подмножество, лишний и чужой ответ не проходят', () {
    final question = HarakaMatchQuestion(
      prompt: harakaTestAtom('ba', 'kasra'),
      options: [
        harakaTestAtom('mim', 'kasra'),
        harakaTestAtom('ba', 'fatha'),
        harakaTestAtom('ra', 'kasra'),
        harakaTestAtom('kaf', 'fatha'),
        harakaTestAtom('ba', 'damma'),
      ],
    );
    final correct = {'vowel.mim.kasra', 'vowel.ra.kasra'};
    expect(question.isCorrect(correct), isTrue);
    expect(question.isCorrect({correct.first}), isFalse);
    expect(question.isCorrect({...correct, 'vowel.ba.fatha'}), isFalse);
    expect(question.isCorrect({...correct, 'vowel.unknown.kasra'}), isFalse);
    expect(question.isCorrect({}), isFalse);
  });

  test('переменное число ответов и ловушки только из переданного пула', () {
    final random = Random(13);
    final counts = <int>{};
    for (var i = 0; i < 60; i++) {
      final question = HarakaMatchQuestion.generate(
        harakaTestSyllables,
        random: random,
      );
      counts.add(question.answerIds.length);
      expect(harakaTestSyllables, contains(question.prompt));
      expect(harakaTestSyllables, containsAll(question.options));
      expect(question.options.map((atom) => atom.id).toSet(), hasLength(6));
      expect(question.options, isNot(contains(question.prompt)));
      expect(
        question.options.any(
          (atom) =>
              atom.letterId == question.prompt.letterId &&
              HarakaSyllables.markIdFor(atom) !=
                  HarakaSyllables.markIdFor(question.prompt),
        ),
        isTrue,
      );
      expect(question.isCorrect(question.answerIds), isTrue);
    }
    expect(counts, {1, 2, 3});
  });
}
