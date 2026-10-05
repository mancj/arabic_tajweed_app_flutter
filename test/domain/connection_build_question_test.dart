// Обычный рендер арабского слова может сам исправить выбранную форму.
// Проверяем, что сборка сохраняет начертание пользователя и независимо
// оценивает форму и знак: иначе неверное соединение выглядит правильным.
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ta = Atom(
    id: 'ta.isolated',
    kind: AtomKind.letterForm,
    display: 'ت',
    letterId: 'ta',
  );
  const ba = Atom(
    id: 'ba.isolated',
    kind: AtomKind.letterForm,
    display: 'ب',
    letterId: 'ba',
  );
  const initial = Atom(
    id: 'ta.initial',
    kind: AtomKind.letterForm,
    display: 'تـ',
    form: LetterForm.initial,
  );
  const baInitial = Atom(
    id: 'ba.initial',
    kind: AtomKind.letterForm,
    display: 'بـ',
    form: LetterForm.initial,
  );
  const baMedial = Atom(
    id: 'ba.medial',
    kind: AtomKind.letterForm,
    display: 'ـبـ',
    form: LetterForm.medial,
  );
  const baFinal = Atom(
    id: 'ba.finalForm',
    kind: AtomKind.letterForm,
    display: 'ـب',
    form: LetterForm.finalForm,
  );
  final question = ConnectionBuildQuestion(
    parts: [
      ConnectionBuildPart(
        form: initial,
        syllable: HarakaSyllables.completeFamily(ta, const []).first,
      ),
      ConnectionBuildPart(
        form: baFinal,
        syllable: HarakaSyllables.completeFamily(ba, const [])[1],
      ),
    ],
    missingIndex: 1,
    formOptions: [baInitial, baMedial, baFinal],
  );

  test('пропуск не раскрывает форму и огласовку', () {
    expect(question.preview(null, null), ['تَ\u200d', null]);
    expect(question.preview('unknown', null).last, isNull);
    expect(question.preview('ba.finalForm', null).last, '\u200dب');
  });

  test('ошибочная начальная форма остаётся начальной в конце связки', () {
    expect(question.preview('ba.initial', 'haraka.kasra').last, 'بِ\u200d');
    expect(question.preview('ba.finalForm', 'haraka.kasra').last, '\u200dبِ');
    expect(
      question.preview('ba.medial', 'haraka.kasra').last,
      '\u200dبِ\u200d',
    );
    expect(question.display, 'تَبِ');
  });

  test('форма и огласовка проверяются независимо', () {
    final wrongForm = question.evaluate(
      formId: 'ba.initial',
      markId: 'haraka.kasra',
    );
    expect(wrongForm.formCorrect, isFalse);
    expect(wrongForm.harakaCorrect, isTrue);
    expect(wrongForm.correct, isFalse);
    final wrongMark = question.evaluate(
      formId: 'ba.finalForm',
      markId: 'haraka.fatha',
    );
    expect(wrongMark.formCorrect, isTrue);
    expect(wrongMark.harakaCorrect, isFalse);
    expect(wrongMark.correct, isFalse);
    expect(
      question.evaluate(formId: 'ba.finalForm', markId: 'haraka.kasra').correct,
      isTrue,
    );
  });
}
