// Вводные сборки появляются с третьей темы огласовок, используют только
// знакомый материал и не вытесняют письмо/голос. При доборе и исправлении
// ошибки их доля не растёт; ранние темы и другие разделы их не получают.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  CurriculumContext before(String topicId) => CurriculumContext(
    progress: {
      for (final topic in curriculum.topics.takeWhile(
        (topic) => topic.id != topicId,
      ))
        for (final id in topic.counterOf)
          id: AtomProgress(
            state: byId[id]!.kind == AtomKind.concept
                ? AtomState.introduced
                : AtomState.known,
            successfulModes: ExerciseMode.values.toSet(),
            cleanStreak: 3,
          ),
    },
    formsByLetter: curriculum.formsByLetter,
  );
  List<Exercise> buildTopic(String id, int seed) {
    final ctx = before(id);
    final topic = curriculum.topics.firstWhere((topic) => topic.id == id);
    return ExerciseGenerator(
      curriculum: curriculum,
      random: Random(seed),
    ).build(
      plan: TopicBoard(curriculum).planFor(topic, ctx, sessionId: 101),
      ctx: ctx,
      sessionId: 101,
    );
  }

  test('первые две темы и соседние разделы не получают вводные сборки', () {
    for (final id in ['m.haraka.intro', 'm.haraka.signs', 'm.haraka.words1']) {
      expect(
        buildTopic(id, 1).where((exercise) => exercise.mode.isWordPreparation),
        isEmpty,
        reason: id,
      );
    }
    final alphabet = curriculum.topics.firstWhere(
      (topic) =>
          topic.stage == 1 &&
          topic.counterOf.any((id) => byId[id]!.kind == AtomKind.letterForm),
    );
    expect(
      buildTopic(
        alphabet.id,
        1,
      ).where((exercise) => exercise.mode.isWordPreparation),
      isEmpty,
    );
    // Ручной возврат к первым знакам тоже не должен включать сборки,
    // даже когда в истории уже пройдены более поздние темы.
    final lateContext = before('m.haraka.group6');
    final signs = curriculum.topics.firstWhere(
      (topic) => topic.id == 'm.haraka.signs',
    );
    final signsReview = ExerciseGenerator(curriculum: curriculum).build(
      plan: TopicBoard(curriculum).planFor(signs, lateContext, sessionId: 101),
      ctx: lateContext,
      sessionId: 101,
    );
    expect(signsReview.where((task) => task.mode.isWordPreparation), isEmpty);
  });

  test('третья тема получает оба формата без потери обязательной практики', () {
    final ctx = before('m.haraka.group1');
    final topic = curriculum.topics.firstWhere(
      (topic) => topic.id == 'm.haraka.group1',
    );
    final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 101);
    final allowedIds = {
      ...ctx.progress.keys,
      ...plan.newAtoms.map((atom) => atom.id),
    };
    for (var seed = 0; seed < 30; seed++) {
      final tasks = buildTopic(topic.id, seed);
      expect(tasks, hasLength(20));
      final preparation = tasks.where((task) => task.mode.isWordPreparation);
      expect(preparation.map((task) => task.mode).toSet(), {
        ExerciseMode.connectionBuild,
        ExerciseMode.wordBuild,
      }, reason: 'seed $seed');
      expect(preparation, hasLength(2));
      expect(
        tasks.where((task) => task.mode.isPronunciation).length,
        lessThanOrEqualTo(3),
      );
      expect(tasks.where((task) => task.isFormMaintenance), hasLength(2));
      for (final atom in plan.newAtoms) {
        expect(
          tasks.where((task) => task.atom == atom).map((task) => task.mode),
          contains(ExerciseMode.drawHarakaForSound),
        );
      }
      for (final task in preparation) {
        final contentId =
            task.connectionBuildQuestion?.contentId ??
            task.wordBuildQuestion?.contentId;
        expect(
          curriculum.wordsForSet('harakaIntroduction').map((word) => word.id),
          contains(contentId),
        );
        final recordedWord = curriculum.words.singleWhere(
          (word) => word.id == contentId,
        );
        expect(task.audioAsset, recordedWord.audioFile);
        expect(
          task.resultAtoms.every((atom) => allowedIds.contains(atom.id)),
          isTrue,
        );
        expect(
          task.resultAtoms.where((atom) => atom.id.startsWith('vowel.ba.')),
          isEmpty,
        );
        for (final syllable in task.sequenceOrder.where(
          (atom) => atom.letterId != 'ba',
        )) {
          expect(allowedIds, contains(syllable.id));
        }
      }
      expect(
        preparation
            .singleWhere((task) => task.mode == ExerciseMode.wordBuild)
            .wordBuildQuestion!
            .display,
        'بِكَ',
      );
    }
  });

  test('слова банка во всех группах используют только доступные слоги', () {
    for (var group = 1; group <= 8; group++) {
      final topicId = 'm.haraka.group$group';
      final ctx = before(topicId);
      final topic = curriculum.topics.firstWhere(
        (topic) => topic.id == topicId,
      );
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 101);
      final availableIds = {
        ...ctx.progress.keys,
        ...plan.newAtoms.map((atom) => atom.id),
      };
      for (var seed = 0; seed < 10; seed++) {
        for (final task in buildTopic(
          topicId,
          seed,
        ).where((task) => task.mode.isWordPreparation)) {
          for (final syllable in task.sequenceOrder) {
            if (syllable.letterId == 'ba') continue;
            expect(availableIds, contains(syllable.id), reason: topicId);
          }
        }
      }
    }
  });

  test('короткие повторы чередуют форматы, добор учитывает общий предел', () {
    final ctx = before('m.haraka.group6');
    final targets = ctx.progress.keys
        .where(
          (id) =>
              byId[id]!.kind == AtomKind.syllable &&
              byId[id]!.audioAsset != null,
        )
        .take(10)
        .toList();
    final plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: targets,
      reviewCounts: {for (final id in targets) id: 1},
      reason: 'повторение',
    );
    List<Exercise> review(
      int sessionId, {
      Set<ExerciseMode> previous = const {},
      int previousTasks = 0,
    }) => ExerciseGenerator(curriculum: curriculum, random: Random(7)).build(
      plan: plan,
      ctx: ctx,
      sessionId: sessionId,
      taskLimit: 10,
      previousWordPreparations: previous,
      previousTaskCount: previousTasks,
    );
    final first = review(101);
    final firstMode = first
        .where((task) => task.mode.isWordPreparation)
        .single
        .mode;
    final nextSessionMode = review(
      102,
    ).where((task) => task.mode.isWordPreparation).single.mode;
    expect(firstMode, isNot(nextSessionMode));
    final remainder = review(
      101,
      previous: {firstMode},
      previousTasks: first.length,
    );
    expect(
      remainder.where((task) => task.mode.isWordPreparation).single.mode,
      isNot(firstMode),
    );
    final exhausted = review(
      101,
      previous: {firstMode, nextSessionMode},
      previousTasks: 10,
    );
    expect(exhausted.where((task) => task.mode.isWordPreparation), isEmpty);
  });

  test(
    'ошибка сборки сохраняет частичные результаты без лишней копии задания',
    () {
      final task = buildTopic(
        'm.haraka.group1',
        7,
      ).firstWhere((task) => task.mode == ExerciseMode.connectionBuild);
      final question = task.connectionBuildQuestion!;
      final result = question.evaluate(
        formId: question.formOptions
            .firstWhere((form) => form.id != question.expectedFormId)
            .id,
        markId: question.expectedMarkId,
      );
      final session = LessonSession(exercises: [task], sessionId: 101);
      session.answer(
        task,
        Exercise.directMiss,
        atomResults: question.atomResults(result),
      );
      expect(session.total, 1);
      expect(session.requeuedCount, 0);
      final wrong = session.log.whereType<ProgressEvent>().toList();
      expect(
        wrong
            .singleWhere(
              (event) => event.atomId == question.missingPart.form.id,
            )
            .correct,
        isFalse,
      );
      expect(
        wrong
            .singleWhere(
              (event) => event.atomId == question.missingPart.harakaAtom.id,
            )
            .correct,
        isTrue,
      );
      session.answer(task, Exercise.directAnswer);
      expect(
        session.log
            .whereType<ProgressEvent>()
            .skip(2)
            .every((event) => event.correct && !event.isClean),
        isTrue,
      );
    },
  );
}
