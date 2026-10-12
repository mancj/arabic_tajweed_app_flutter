// Слова получают короткую практику без многократной полной сборки,
// сохраняют собственный прогресс, обязательную полную сборку и интервалы.
// Проверяем настоящий банк: разрывы, длинные слова, записи и снятие подсказок.
// Выбор звучания по написанному слову не возвращается в повторах и доборе.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
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
  final topics = curriculum.topics.where((topic) => topic.stage == 3).toList();
  const rules = LearningRules();
  final now = DateTime(2026, 10, 8);

  CurriculumContext context(Map<String, AtomProgress> progress) =>
      CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );

  Map<String, AtomProgress> before(Topic topic) => {
    for (final prior in curriculum.topics.takeWhile((t) => t.id != topic.id))
      for (final id in prior.counterOf)
        id: AtomProgress(
          state: byId[id]!.kind == AtomKind.concept
              ? AtomState.introduced
              : AtomState.known,
          knownAt: now,
          successfulModes: rules.requiredPracticeModes(byId[id]!),
          cleanStreak: 3,
        ),
  };

  test('каждый набор получает сборки и чтение по своим записям', () {
    for (final topic in topics) {
      final ctx = context(before(topic));
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
      final tasks = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(5),
      ).build(plan: plan, ctx: ctx, sessionId: 100);
      expect(tasks.length, lessThanOrEqualTo(rules.tasksPerSession));
      final voice = tasks
          .where((task) => task.mode == ExerciseMode.sayWord)
          .toList();
      expect(voice, isNotEmpty);
      expect(voice.length, lessThanOrEqualTo(3));
      expect(voice.map((task) => task.atom.id).toSet().length, voice.length);
      for (final word in plan.newAtoms.where(
        (atom) => atom.kind == AtomKind.word,
      )) {
        final ownTasks = tasks.where((task) => task.atom == word).toList();
        expect(ownTasks.length, lessThanOrEqualTo(3));
        expect(
          ownTasks.map((task) => task.mode),
          isNot(contains(ExerciseMode.letterToSound)),
        );
        expect(
          ownTasks.map((task) => task.mode),
          containsAll([ExerciseMode.soundToLetter, ExerciseMode.wordBuild]),
        );
        final length = curriculum.words
            .singleWhere((example) => example.id == word.wordId)
            .syllableIds
            .length;
        for (final task in ownTasks.where((task) => task.isChoice)) {
          expect(
            task.options.map(
              (option) => curriculum.words
                  .singleWhere((example) => example.id == option.wordId)
                  .syllableIds
                  .length,
            ),
            everyElement(length),
            reason: 'При наличии похожих слов длина не должна выдавать ответ',
          );
        }
        for (final task in ownTasks.where(
          (task) => task.mode.isWordPreparation,
        )) {
          expect(task.resultAtoms, [word]);
          expect(task.audioAsset, word.audioAsset);
          expect(
            task.wordBuildQuestion?.contentId ??
                task.connectionBuildQuestion?.contentId,
            word.wordId,
          );
          if (task.wordBuildQuestion case final question?) {
            expect(question.display, word.display);
            expect(question.showLetterHints, isTrue);
          }
        }
      }
      final session = LessonSession(exercises: tasks, sessionId: 100);
      while (!session.isFinished) {
        final task = session.current!;
        session.answer(task, task.answerIndex);
      }
      expect(
        session.log.map((entry) => byId[entry.atomId]!.kind),
        everyElement(AtomKind.word),
      );
    }
  });

  test('повторение и добор слов не возвращают выбор звучания', () {
    final topic = topics.last;
    final word = byId[topic.counterOf.last]!;
    final plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: [word.id],
      reason: 'повторение слова',
    );
    for (final state in [
      AtomState.introduced,
      AtomState.learning,
      AtomState.known,
      AtomState.mastered,
    ]) {
      final progress = before(topic);
      progress[word.id] = AtomProgress(
        state: state,
        cleanStreak: 3,
        successfulModes: const {
          ExerciseMode.wordBuild,
          ExerciseMode.letterToSound,
          ExerciseMode.sayWord,
        },
      );
      for (final voiceEnabled in [true, false]) {
        final generator = ExerciseGenerator(
          curriculum: curriculum,
          rules: rules.copyWith(requirePronunciation: voiceEnabled),
        );
        final ctx = context(progress);
        final first = generator.build(
          plan: plan,
          ctx: ctx,
          sessionId: 100,
          taskLimit: 2,
        );
        final extra = generator.build(
          plan: plan,
          ctx: ctx,
          sessionId: 100,
          taskLimit: 3,
          previousCounts: {word.id: first.length},
          previousPronunciations: {
            for (final task in first)
              if (task.mode.isPronunciation) task.atom.id,
          },
          previousTaskCount: first.length,
        );
        expect(first, isNotEmpty);
        expect(
          [...first, ...extra].map((task) => task.mode),
          isNot(contains(ExerciseMode.letterToSound)),
        );
      }
    }
  });

  test('известное слово без полной сборки остаётся в практике', () {
    final topic = topics.first;
    final progress = before(topic);
    for (final id in topic.counterOf) {
      progress[id] = AtomProgress(
        state: byId[id]!.kind == AtomKind.concept
            ? AtomState.introduced
            : AtomState.known,
        cleanStreak: 3,
        successfulModes: const {
          ExerciseMode.soundToLetter,
          ExerciseMode.letterToSound,
        },
      );
    }
    final board = TopicBoard(curriculum);
    expect(
      board
          .statuses(context(progress))
          .firstWhere((s) => s.topic.id == topic.id)
          .isDone,
      isFalse,
    );
    final word = byId[topic.counterOf.last]!;
    final tasks = ExerciseGenerator(curriculum: curriculum).build(
      plan: LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: [word.id],
        reviewCounts: {word.id: 1},
        reason: 'добор сборки',
      ),
      ctx: context(progress),
      sessionId: 100,
      taskLimit: 1,
    );
    expect(tasks.single.mode, ExerciseMode.wordBuild);
    expect(tasks.single.wordBuildQuestion!.showLetterHints, isFalse);
    for (final id in topic.counterOf.where(
      (id) => byId[id]!.kind == AtomKind.word,
    )) {
      progress[id] = progress[id]!.copyWith(
        successfulModes: {ExerciseMode.wordBuild, ExerciseMode.sayWord},
      );
    }
    expect(
      board
          .statuses(context(progress))
          .firstWhere((s) => s.topic.id == topic.id)
          .isDone,
      isTrue,
    );
  });

  test('добор учитывает голос всей сессии, отключение сохраняет сборку', () {
    final topic = topics[3];
    final progress = before(topic);
    final ctx = context(progress);
    final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
    final generator = ExerciseGenerator(curriculum: curriculum);
    final tasks = generator.build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      taskLimit: 12,
    );
    final spoken = tasks
        .where((task) => task.mode.isPronunciation)
        .map((task) => task.atom.id)
        .toSet();
    final counts = <String, int>{};
    for (final task in tasks) {
      counts.update(task.atom.id, (count) => count + 1, ifAbsent: () => 1);
    }
    final extra = generator.build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      taskLimit: 20 - tasks.length,
      previousCounts: counts,
      previousPronunciations: spoken,
      previousTaskCount: tasks.length,
    );
    final extraVoice = extra
        .where((task) => task.mode.isPronunciation)
        .toList();
    expect(spoken.length + extraVoice.length, lessThanOrEqualTo(3));
    expect(extraVoice.any((task) => spoken.contains(task.atom.id)), isFalse);
    final disabled = ExerciseGenerator(
      curriculum: curriculum,
      rules: rules.copyWith(requirePronunciation: false),
    ).build(plan: plan, ctx: ctx, sessionId: 101);
    expect(disabled.any((task) => task.mode.isPronunciation), isFalse);
    expect(disabled.any((task) => task.mode == ExerciseMode.wordBuild), isTrue);
  });

  test(
    'полная сборка закрепляет слово с прежними календарными интервалами',
    () {
      final word = curriculum.wordsForSet('wordReading').first;
      final fold = ProgressFold(
        letterFormIds: curriculum.letterFormIds,
        baseLetterIds: curriculum.baseLetterIds,
        wordAtomIds: curriculum.wordAtomIds,
      );
      ProgressEvent event(String id, ExerciseMode mode, int day) =>
          ProgressEvent(
            atomId: id,
            sessionId: day + 1,
            at: now.add(Duration(days: day)),
            mode: mode,
            correct: true,
            attempt: 1,
            fastEnough: true,
          );
      final log = [
        event(word.atomId!, ExerciseMode.connectionBuild, 0),
        event(word.atomId!, ExerciseMode.wordBuild, 0),
        event(word.atomId!, ExerciseMode.soundToLetter, 0),
      ];
      final known = fold.fold(log)[word.atomId]!;
      expect(known.state, AtomState.known);
      expect(known.reviewIntervalFor(rules), rules.reviewIntervalBase);
      for (final day in [1, 3, 7, 14]) {
        log.add(event(word.atomId!, ExerciseMode.wordBuild, day));
      }
      expect(fold.fold(log)[word.atomId]!.state, AtomState.mastered);
      expect(
        fold.fold([
          event('ba.initial', ExerciseMode.wordBuild, 0),
        ])['ba.initial']!.hadActiveSuccess,
        isFalse,
      );
    },
  );
}
