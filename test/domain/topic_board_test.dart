import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  final board = TopicBoard(curriculum);

  CurriculumContext ctxOf(Map<String, AtomState> states) => CurriculumContext(
    progress: {
      for (final e in states.entries) e.key: AtomProgress(state: e.value),
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

  test('замок называет урок, который его держит', () {
    // Уроки открываются по порядку, и замок объясняет себя тем, что его
    // на самом деле держит: непройденной предыдущей темой.
    final hint = statusOf('m.forms', ctxOf({})).hint;
    expect(hint, contains('сначала пройдите'));
    expect(hint, contains(curriculum.topics.first.title));
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
}
