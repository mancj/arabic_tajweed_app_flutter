import 'dart:io';
import 'dart:math';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/progress_repository.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/knowledge_check.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Проверяет весь адаптивный путь: нельзя пропускать формы, запереть уже
/// открытое после ошибки или выдать знания по незавершённой диагностике.
void main() {
  final course = CurriculumLoader.merge([
    for (final s in ['stage1', 'stage2', 'stage3'])
      CurriculumLoader.parse(
        File('assets/curriculum/$s.json').readAsStringSync(),
      ),
  ]);
  final fold = ProgressFold(
    letterFormIds: course.letterFormIds,
    baseLetterIds: course.baseLetterIds,
  );
  CurriculumContext ctx(Map<String, AtomProgress> p) =>
      CurriculumContext(progress: p, formsByLetter: course.formsByLetter);
  final now = DateTime(2026, 9, 9);

  test('объяснений недостаточно для открытия форм', () {
    final p = {
      for (final id in course.topics.first.counterOf)
        id: const AtomProgress(state: AtomState.introduced),
    };
    final plan = LessonPlanner(
      curriculum: course,
    ).plan(ctx: ctx(p), sessionId: 2, sessionsWithoutNew: 0);
    expect(plan.newAtoms, isEmpty);
    expect(plan.reviewAtoms, isNotEmpty);
    expect(TopicBoard(course).statuses(ctx(p))[1].state, TopicState.locked);
  });

  test('ошибка не закрывает ранее доступную тему', () {
    final p = {
      for (final id in course.topics.first.counterOf)
        id: AtomProgress(state: AtomState.learning, knownAt: now),
    };
    expect(TopicBoard(course).statuses(ctx(p))[1].canPractice, isTrue);
  });

  test(
    'короткая проверка охватывает недостающие буквы и не спрашивает освоенное',
    () {
      final check = KnowledgeCheck(
        curriculum: course,
        topic: course.topics[1],
        context: ctx({
          'ba.isolated': AtomProgress(state: AtomState.known, knownAt: now),
        }),
        random: Random(1),
      );
      expect(check.questions.where((q) => q.atom.id == 'ba.isolated'), isEmpty);
      for (final id in ['alif.isolated', 'ta.isolated', 'tha.isolated']) {
        expect(check.questions.where((q) => q.atom.id == id).length, 2);
      }
      expect(check.isCondensed, isFalse);
      for (final q in check.questions) {
        expect(q.options[q.answerIndex], q.atom);
        expect(
          q.options.map((a) => a.display).toSet().length,
          q.options.length,
        );
        expect(q.options.map((a) => a.label).toSet().length, q.options.length);
      }
    },
  );

  test('далёкая тема проверяется максимум двадцатью вопросами', () {
    final topic = course.topics.firstWhere((t) => t.id == 'm.haraka.intro');
    final check = KnowledgeCheck(
      curriculum: course,
      topic: topic,
      context: ctx({}),
      random: Random(1),
    );
    expect(check.atoms.length, greaterThan(80));
    expect(check.questions, hasLength(20));
    expect(check.checkedAtoms, hasLength(10));
    expect(check.inferredAtoms, isNotEmpty);
    expect(
      check.atoms.map((atom) => atom.id).toSet(),
      containsAll(
        course.topics
            .takeWhile((candidate) => candidate.id != topic.id)
            .expand((candidate) => candidate.counterOf),
      ),
      reason: 'переход должен закрыть весь путь до выбранной темы',
    );
    expect(
      check.checkedAtoms.map((a) => a.form).toSet(),
      containsAll([
        LetterForm.isolated,
        LetterForm.finalForm,
        LetterForm.initial,
        LetterForm.medial,
      ]),
    );
    expect(
      check.questions.every(
        (q) => q.options[q.answerIndex] == q.atom && q.options.length >= 2,
      ),
      isTrue,
    );
  });

  test('проверка поздней темы умеет спрашивать слова по звучанию', () {
    final topic = course.topics.firstWhere((t) => t.id == 'm.haraka.words3');
    final check = KnowledgeCheck(
      curriculum: course,
      topic: topic,
      context: ctx({}),
      random: Random(1),
    );
    expect(check.questions.length, lessThanOrEqualTo(20));
    expect(
      check.questions.where((q) => q.atom.kind == AtomKind.word),
      isNotEmpty,
    );
    expect(
      check.questions
          .where((q) => q.atom.kind == AtomKind.word)
          .every((q) => q.atom.audioAsset != null && q.options.length >= 2),
      isTrue,
    );
  });

  test(
    'подтверждённое сохраняется после перезапуска и не понижает mastered',
    () async {
      final db = ProgressDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ProgressRepository(
        database: db,
        letterFormIds: course.letterFormIds,
      );
      await repo.record(
        KnowledgeConfirmed(atomId: 'ba.initial', sessionId: 3, at: now),
      );
      final restored = await ProgressRepository(
        database: db,
        letterFormIds: course.letterFormIds,
      ).of('ba.initial');
      expect(restored.state, AtomState.known);
      expect(restored.weak, isTrue);
      expect(restored.knownAt, now);
      final result = fold.foldOnto(
        {'ba.initial': const AtomProgress(state: AtomState.mastered)},
        [KnowledgeConfirmed(atomId: 'ba.initial', sessionId: 4, at: now)],
      );
      expect(result['ba.initial']!.state, AtomState.mastered);
    },
  );

  test('весь курс доходит до освоения без пропусков и пустых занятий', () {
    var p = <String, AtomProgress>{};
    var withoutNew = 0;
    var complete = false;
    int? connectionSession;
    int? harakatSession;
    int? lastBaseSession;
    for (var session = 1; session <= 250; session++) {
      final plan = LessonPlanner(
        curriculum: course,
      ).plan(ctx: ctx(p), sessionId: session, sessionsWithoutNew: withoutNew);
      if (plan.topicId == 'm.join') {
        connectionSession ??= session;
        expect(
          TopicBoard(course)
              .statuses(ctx(p))
              .where((s) => s.topic.stage == 1)
              .every((s) => s.isDone),
          isTrue,
          reason: 'модуль соединений начался до завершения алфавита',
        );
      }
      if (plan.topicId == 'm.haraka.intro') harakatSession ??= session;
      if (plan.newAtoms.any((a) => a.id == 'ya.isolated')) {
        lastBaseSession ??= session;
      }
      if (plan.topicId != null && plan.newAtoms.isNotEmpty) {
        final unit = course.topics.firstWhere((t) => t.id == plan.topicId);
        expect({
          ...plan.newAtoms.map((a) => a.id),
          ...plan.reviewAtoms,
        }, unit.counterOf.toSet());
      }
      final intro = [
        for (final a in plan.newAtoms)
          AtomIntroduced(
            atomId: a.id,
            sessionId: session,
            at: now.add(Duration(days: session)),
          ),
      ];
      p = fold.foldOnto(p, intro);
      final exercises = ExerciseGenerator(
        curriculum: course,
        random: Random(session),
      ).build(plan: plan, ctx: ctx(p), sessionId: session);
      expect(exercises, isNotEmpty, reason: 'пустое занятие $session');
      expect(exercises.length, lessThanOrEqualTo(20));
      expect(
        exercises
            .where((e) => e.atom.kind == AtomKind.syllable)
            .every((e) => e.isChoice),
        isTrue,
      );
      final lesson = LessonSession(
        exercises: exercises,
        sessionId: session,
        now: () => now.add(Duration(days: session)),
      );
      while (!lesson.isFinished) {
        final e = lesson.current!;
        lesson.answer(e, e.answerIndex);
      }
      p = fold.foldOnto(p, lesson.log);
      withoutNew = plan.newAtoms.isEmpty ? withoutNew + 1 : 0;
      complete = TopicBoard(course).statuses(ctx(p)).every((s) => s.isDone);
      if (complete) break;
    }
    expect(
      complete,
      isTrue,
      reason:
          'не освоены: ${p.entries.where((e) => e.value.state.index < AtomState.known.index && !e.key.startsWith('concept.')).map((e) => '${e.key}: ${e.value.state} streak=${e.value.cleanStreak} modes=${e.value.modesInStreak}')} ',
    );
    expect(connectionSession, isNotNull);
    expect(harakatSession, isNotNull);
    expect(connectionSession!, greaterThan(harakatSession!));
    expect(connectionSession, greaterThan(lastBaseSession!));
  });
}
