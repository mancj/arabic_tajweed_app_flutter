import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  final board = TopicBoard(curriculum);

  CurriculumContext ctxOf(Map<String, AtomState> states) => CurriculumContext(
    progress: {
      for (final e in states.entries)
        e.key: AtomProgress(
          state: e.value,
          successfulModes: e.value.index >= AtomState.known.index
              ? const LearningRules().requiredPracticeModes(
                  curriculum.nodes.firstWhere((n) => n.atom.id == e.key).atom,
                )
              : const {},
        ),
    },
    formsByLetter: const {},
  );

  TopicStatus statusOf(String id, CurriculumContext ctx) =>
      board.statuses(ctx).firstWhere((s) => s.topic.id == id);

  const firstLesson = [
    'concept.letter',
    'alif.isolated',
    'ba.isolated',
    'ta.isolated',
    'tha.isolated',
  ];

  test('первая тема — это первый урок целиком', () {
    // Тема и есть урок: объяснение про алфавит плюс четыре буквы.
    // Понятие в одиночку уроком не было — спросить его нечем.
    final plan = board.planFor(statusOf('m.first', ctxOf({})).topic, ctxOf({}));
    expect(plan.newAtoms.map((a) => a.id), firstLesson);
  });

  test('на старте открыта только первая тема', () {
    final statuses = board.statuses(ctxOf({}));
    expect(statuses.first.state, TopicState.available);
    expect(
      statuses.skip(1).map((s) => s.state),
      everyElement(TopicState.locked),
    );
  });

  test('замок объясняет необходимые знания', () {
    // Завершённое занятие не гарантирует освоенности его материала.
    final hint = statusOf('m.forms', ctxOf({})).hint;
    expect(hint, contains('нужно освоить'));
    expect(hint, contains('4 буквы'));
  });

  test('понятие засчитывается по знакомству, а не по known', () {
    final ctx = ctxOf({'concept.letter': AtomState.introduced});
    expect(statusOf('m.first', ctx).done, 1);
  });

  test('буква засчитывается только с known', () {
    expect(
      statusOf('m.first', ctxOf({'ba.isolated': AtomState.introduced})).done,
      0,
    );
    expect(
      statusOf('m.first', ctxOf({'ba.isolated': AtomState.known})).done,
      1,
    );
  });

  test('отключённый голос не мешает завершить освоенную букву', () {
    final ctx = CurriculumContext(
      progress: {
        'ba.isolated': const AtomProgress(
          state: AtomState.known,
          successfulModes: {ExerciseMode.trace, ExerciseMode.traceFromMemory},
        ),
      },
      formsByLetter: const {},
    );

    expect(board.isDone('ba.isolated', ctx), isFalse);
    expect(
      TopicBoard(
        curriculum,
        rules: const LearningRules(requirePronunciation: false),
      ).isDone('ba.isolated', ctx),
      isTrue,
    );
  });

  test('тема делит атомы на новые и знакомые', () {
    final ctx = ctxOf({
      'concept.letter': AtomState.introduced,
      'alif.isolated': AtomState.known,
      'ba.isolated': AtomState.known,
    });
    final plan = board.planFor(statusOf('m.first', ctx).topic, ctx);

    expect(plan.newAtoms.map((a) => a.id), ['ta.isolated', 'tha.isolated']);
    expect(plan.reviewAtoms, [
      'concept.letter',
      'alif.isolated',
      'ba.isolated',
    ]);
  });

  test('урок форм включает все начертания темы за один сеанс', () {
    // Иначе урок отмечается пройденным после конечных форм, хотя
    // начальные и срединные ученик ещё не видел.
    final ctx = ctxOf({for (final id in firstLesson) id: AtomState.known});
    final plan = board.planFor(statusOf('m.forms', ctx).topic, ctx);

    expect(plan.newAtoms.map((a) => a.id), [
      'concept.forms',
      'alif.finalForm',
      'ba.finalForm',
      'ba.initial',
      'ba.medial',
      'ta.finalForm',
      'ta.initial',
      'ta.medial',
      'tha.finalForm',
      'tha.initial',
      'tha.medial',
    ]);

    final next = ctxOf({
      for (final a in plan.newAtoms) a.id: AtomState.known,
      for (final id in firstLesson) id: AtomState.known,
    });
    expect(
      board
          .planFor(statusOf('m.forms', next).topic, next)
          .newAtoms
          .map((a) => a.id),
      isEmpty,
    );
  });

  // Иначе изменение зависимостей оставит только часть форм, а урок всё
  // равно откроет следующую тему после сокращённого набора упражнений.
  test('недоступные формы не исключаются из темы молча', () {
    final ctx = ctxOf({'ba.isolated': AtomState.introduced});
    expect(
      () => board.planFor(statusOf('m.forms', ctx).topic, ctx),
      throwsStateError,
    );
  });

  // Укрупнение тем нельзя компенсировать пропуском форм. Ошибка должна
  // обнаружиться при составлении плана, ещё до объяснений и заданий.
  test('слишком большую тему нужно разделить в программе курса', () {
    final forms = curriculum.nodes.where(
      (n) => n.atom.form != null && n.atom.form != LetterForm.isolated,
    );
    final topic = Topic(
      id: 'all.forms',
      stage: 1,
      title: 'Все формы',
      requirement: const Always(),
      counterOf: forms.map((n) => n.atom.id).toList(),
    );
    final ctx = ctxOf({
      for (final n in curriculum.nodes)
        if (n.atom.form == LetterForm.isolated) n.atom.id: AtomState.introduced,
    });
    expect(() => board.planFor(topic, ctx), throwsStateError);
  });

  test('буквы с одной формой идут в урок все разом', () {
    // У ـد ـذ ـر ـز форма одна — конечная, значит и заход один.
    final ctx = ctxOf({
      for (final id in firstLesson) id: AtomState.known,
      for (final id in ['dal', 'dhal', 'ra', 'zay'])
        '$id.isolated': AtomState.known,
    });
    final plan = board.planFor(statusOf('m.nojoin.forms', ctx).topic, ctx);

    expect(plan.newAtoms.map((a) => a.id), [
      'dal.finalForm',
      'dhal.finalForm',
      'ra.finalForm',
      'zay.finalForm',
    ]);
  });

  test('пройденная тема уходит в чистое повторение', () {
    final ctx = ctxOf({for (final id in firstLesson) id: AtomState.known});
    final plan = board.planFor(statusOf('m.first', ctx).topic, ctx);

    expect(plan.newAtoms, isEmpty);
    expect(plan.reviewAtoms, firstLesson);
    expect(plan.reason, contains('повторение'));
  });

  test('закрытую тему повторить нельзя', () {
    final statuses = board.statuses(ctxOf({}));
    expect(statuses.first.canPractice, isTrue);
    expect(statuses.skip(1).every((s) => s.canPractice), isFalse);
  });

  test('склонение в условии не ломается', () {
    expect(board.describe(const LettersKnown(1)), 'нужно 1 букву');
    expect(board.describe(const LettersKnown(2)), 'нужно 2 буквы');
    expect(board.describe(const LettersKnown(8)), 'нужно 8 букв');
    expect(board.describe(const LettersKnown(11)), 'нужно 11 букв');
  });

  test('возврат в частично пройденную тему добирает все оставшиеся формы', () {
    final sinForms = statusOf('m.sin.forms', ctxOf({})).topic;
    final known = {
      for (final t in curriculum.topics.takeWhile((t) => t.id != 'm.sin.forms'))
        for (final id in t.counterOf) id: AtomState.known,
    };

    final first = board.planFor(sinForms, ctxOf(known));
    expect(first.newAtoms.map((a) => a.id), [
      'sin.finalForm',
      'sin.initial',
      'sin.medial',
      'shin.finalForm',
      'shin.initial',
      'shin.medial',
    ]);

    final second = board.planFor(
      sinForms,
      ctxOf({
        ...known,
        'sin.finalForm': AtomState.known,
        'shin.finalForm': AtomState.learning,
      }),
    );
    expect(second.newAtoms.map((a) => a.id), [
      'sin.initial',
      'sin.medial',
      'shin.initial',
      'shin.medial',
    ]);
  });
}
