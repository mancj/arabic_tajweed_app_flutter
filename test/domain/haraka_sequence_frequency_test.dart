// Защищает от возвращения редких сборок только на ба и алифе: реальные
// уроки получают до трёх разных букв, а новые слоги сначала объясняются.
// Обязательное чтение и письмо, длина урока и предел всей сессии сохраняются.
// Две сборки смешивают буквы и повторяют знаки, чтобы ответ нельзя было
// угадать исключением. Пересчёт плана учитывает число выполненных сборок,
// а короткий добор сохраняет их долю вместо всех двух сразу.
// Сборка одного слога делит одиночные места с двумя направлениями выбора,
// использует только знакомые буквы и знаки и не вытесняет письмо.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/lesson_explanation_queue.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  const readingModes = {
    ExerciseMode.soundToLetter,
    ExerciseMode.letterToSound,
    ExerciseMode.syllableBuild,
  };

  void expectBalanced(List<Exercise> exercises) {
    final counts = [
      for (final mode in readingModes)
        exercises
            .where((e) => e.mode == mode && e.atom.kind == AtomKind.syllable)
            .length,
    ];
    expect(
      maxBy(counts, (count) => count)! - minBy(counts, (count) => count)!,
      lessThanOrEqualTo(1),
    );
    expect(counts.last, greaterThanOrEqualTo(1));
  }

  CurriculumContext before(Topic target) => CurriculumContext(
    progress: {
      for (final (index, topic)
          in curriculum.topics
              .takeWhile((topic) => topic.id != target.id)
              .indexed)
        for (final id in topic.counterOf)
          id: AtomProgress(
            state: byId[id]!.kind == AtomKind.concept
                ? AtomState.introduced
                : AtomState.known,
            cleanStreak: 3,
            successfulModes: ExerciseMode.values.toSet(),
            introducedSession: index + 1,
            lastSeenSession: index + 1,
            weak: true,
          ),
    },
    formsByLetter: curriculum.formsByLetter,
  );

  test('темы получают сборки только на текущих и уже изученных буквах', () {
    for (final topic in curriculum.topics.where(
      (topic) => topic.id.startsWith('m.haraka.group'),
    )) {
      final ctx = before(topic);
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
      for (var seed = 0; seed < 20; seed++) {
        final exercises = ExerciseGenerator(
          curriculum: curriculum,
          random: Random(seed),
        ).build(plan: plan, ctx: ctx, sessionId: 100);
        final sequences = exercises
            .where((e) => e.mode.isHarakaSequence)
            .toList();
        expect(exercises, hasLength(20), reason: topic.id);
        expectBalanced(exercises);
        final families = byId.values
            .where(
              (atom) =>
                  atom.kind == AtomKind.syllable &&
                  atom.tracing != null &&
                  (ctx.isKnown(atom.id) || plan.newAtoms.contains(atom)),
            )
            .groupListsBy((atom) => atom.letterId);
        final completeFamilies = families.values.where(
          (family) => family.length == 3,
        );
        expect(
          sequences.length,
          lessThanOrEqualTo(min(3, completeFamilies.length)),
        );
        if (completeFamilies.any(
          (family) => family.every(plan.newAtoms.contains),
        )) {
          expect(sequences, isNotEmpty, reason: '${topic.id}, seed $seed');
        }
        expect(
          sequences.map((e) => e.atom.letterId).toSet(),
          hasLength(sequences.length),
        );
        expect(
          sequences
              .expand((e) => e.resultAtoms)
              .every(
                (atom) => ctx.isKnown(atom.id) || plan.newAtoms.contains(atom),
              ),
          isTrue,
          reason: 'Будущие темы не вводятся случайной сборкой',
        );
        expect(
          sequences.where((e) => e.mode == ExerciseMode.harakaForLetters),
          hasLength(sequences.length >= 3 ? 2 : 0),
        );
        for (final atom in plan.newAtoms) {
          final modes = exercises
              .where((e) => e.resultAtoms.contains(atom))
              .map((e) => e.mode)
              .toSet();
          expect(
            modes.intersection({
              ...readingModes,
              ExerciseMode.harakaSequence,
              ExerciseMode.harakaForLetters,
            }),
            isNotEmpty,
          );
          expect(modes, contains(ExerciseMode.drawHarakaForSound));
          expect(
            exercises
                .where(
                  (e) => e.atom == atom && e.mode == ExerciseMode.saySyllable,
                )
                .length,
            lessThanOrEqualTo(1),
          );
        }
        for (final exercise in exercises.where(
          (e) => e.mode == ExerciseMode.syllableBuild,
        )) {
          final question = exercise.syllableBuildQuestion!;
          expect(question.prompt, exercise.atom);
          expect(question.letterOptions, hasLength(3));
          expect(
            question.letterOptions.map((a) => a.letterId).toSet(),
            hasLength(3),
          );
          expect(
            question.letterOptions.every(
              (a) =>
                  a.form == LetterForm.isolated &&
                  ctx.stateOf(a.id) != AtomState.fresh,
            ),
            isTrue,
          );
          expect(
            question.letterOptions.map((a) => a.letterId),
            contains(exercise.atom.letterId),
          );
          expect(exercise.isChoice, isFalse);
          expect(exercise.answer, exercise.atom);
          expect(exercise.resultAtoms, [exercise.atom]);
        }
        for (final sequence in sequences) {
          expect(sequence.options, hasLength(3));
          if (sequence.mode == ExerciseMode.harakaForLetters) {
            expect(
              sequence.resultAtoms.map((a) => a.letterId).toSet(),
              hasLength(3),
            );
            expect(
              sequence.resultAtoms
                  .map(HarakaSyllables.markIdFor)
                  .toSet()
                  .length,
              lessThan(3),
            );
            expect(sequence.options.map((a) => a.id).toSet(), {
              'haraka.fatha',
              'haraka.kasra',
              'haraka.damma',
            });
            expect(sequence.options.every((a) => a.audioAsset == null), isTrue);
          } else {
            expect(sequence.options.map((atom) => atom.letterId).toSet(), {
              sequence.atom.letterId,
            });
          }
          for (final atom in sequence.introductionAtoms) {
            expect(byId.containsKey(atom.id), isFalse);
            expect(File('assets/${atom.audioAsset}').existsSync(), isTrue);
            expect(HarakaSyllables.explanationFor(atom), isNotNull);
          }
        }
      }
    }
  });

  test('повтор с одним обратным тестом на слог тоже получает три сборки', () {
    final ctx = before(
      curriculum.topics.firstWhere((topic) => topic.id == 'm.join'),
    );
    final atoms = byId.values
        .where(
          (atom) =>
              const {
                'ra',
                'sod',
                'dod',
                'to',
                'zho',
                'ghayn',
                'qof',
              }.contains(atom.letterId) &&
              atom.kind == AtomKind.syllable &&
              ctx.isKnown(atom.id),
        )
        .take(20)
        .toList();
    final plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: atoms.map((atom) => atom.id).toList(),
      reviewCounts: {for (final atom in atoms) atom.id: 1},
      reason: 'смешанный повтор освоенных слогов',
    );
    final generator = ExerciseGenerator(
      curriculum: curriculum,
      random: Random(8),
      rules: const LearningRules(requirePronunciation: false),
    );
    final exercises = generator.build(plan: plan, ctx: ctx, sessionId: 100);
    expect(exercises, hasLength(20));
    final sequences = exercises.where((e) => e.mode.isHarakaSequence);
    expect(sequences, hasLength(3));
    expect(
      sequences.where((e) => e.mode == ExerciseMode.harakaForLetters),
      hasLength(2),
    );
    expectBalanced(exercises);
    final followUp = generator.build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      previousHarakaSequences: {'ba', 'alif'},
    );
    expect(followUp.where((e) => e.mode.isHarakaSequence), hasLength(1));
    final afterMixed = generator.build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      previousMixedHarakaSequences: 1,
    );
    expect(afterMixed.where((e) => e.mode.isHarakaSequence), hasLength(2));
    expect(
      afterMixed.where((e) => e.mode == ExerciseMode.harakaForLetters),
      hasLength(1),
    );
    final afterBothMixed = generator.build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      previousMixedHarakaSequences: 2,
    );
    expect(
      afterBothMixed.where((e) => e.mode == ExerciseMode.harakaSequence),
      hasLength(1),
    );
    expect(
      afterBothMixed.where((e) => e.mode == ExerciseMode.harakaForLetters),
      isEmpty,
    );
    final afterLimit = generator.build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      previousHarakaSequences: {'alif'},
      previousMixedHarakaSequences: 2,
    );
    expect(afterLimit.where((e) => e.mode.isHarakaSequence), isEmpty);

    final shortAtoms = atoms.take(8).toList();
    final shortPlan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: shortAtoms.map((atom) => atom.id).toList(),
      reviewCounts: {for (final atom in shortAtoms) atom.id: 1},
      reason: 'короткий добор освоенных слогов',
    );
    final short = generator.build(
      plan: shortPlan,
      ctx: ctx,
      sessionId: 100,
      taskLimit: 8,
    );
    expect(short, hasLength(8));
    expect(short.where((e) => e.mode.isHarakaSequence), hasLength(2));
    expect(
      short.where((e) => e.mode == ExerciseMode.harakaForLetters),
      hasLength(1),
    );
    expectBalanced(short);
    final continued = generator.build(
      plan: shortPlan,
      ctx: ctx,
      sessionId: 100,
      taskLimit: 8,
      previousSyllableChoices: const {ExerciseMode.syllableBuild: 6},
    );
    expect(
      continued.where((e) => e.mode == ExerciseMode.syllableBuild),
      isEmpty,
    );
  });

  test('сборка слога ждёт трёх знакомых знаков и минимум трёх букв', () {
    final full = before(
      curriculum.topics.firstWhere((topic) => topic.id == 'm.haraka.group1'),
    );
    final topic = curriculum.topics.firstWhere(
      (topic) => topic.id == 'm.haraka.group1',
    );
    final plan = TopicBoard(curriculum).planFor(topic, full, sessionId: 100);
    for (final progress in [
      {...full.progress}..remove('haraka.damma'),
      {...full.progress}..removeWhere(
        (id, _) =>
            byId[id]?.form == LetterForm.isolated &&
            !{'ta', 'kaf'}.contains(byId[id]?.letterId),
      ),
    ]) {
      final ctx = CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );
      final exercises = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(4),
      ).build(plan: plan, ctx: ctx, sessionId: 100);
      expect(
        exercises.where((e) => e.mode == ExerciseMode.syllableBuild),
        isEmpty,
      );
      expect(exercises, hasLength(20));
    }
  });

  test('слоги текущей темы объясняются до сборки и остаются в журнале', () {
    final topic = curriculum.topics.firstWhere(
      (t) => t.id == 'm.haraka.group6',
    );
    final ctx = before(topic);
    final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
    final exercise =
        ExerciseGenerator(curriculum: curriculum, random: Random(1))
            .build(plan: plan, ctx: ctx, sessionId: 100)
            .firstWhere((e) => e.mode.isHarakaSequence);
    final explanations = LessonExplanationQueue(curriculum)..activate(plan);
    explanations.prepareFor(exercise);
    final shown = <String>{};
    while (explanations.card != null) {
      final atom = explanations.card!;
      shown.add(atom.id);
      explanations.dismissCard();
    }
    expect(exercise.introductionAtoms, isEmpty);
    final newAtoms = exercise.resultAtoms
        .where(plan.newAtoms.contains)
        .toList();
    expect(newAtoms, isNotEmpty);
    expect(shown, containsAll(newAtoms.map((a) => a.id)));
    final fold = ProgressFold(letterFormIds: curriculum.letterFormIds);
    final progress = fold.fold([
      for (final atom in exercise.resultAtoms)
        ProgressEvent(
          atomId: atom.id,
          sessionId: 100,
          at: DateTime(2026, 10, 3),
          mode: exercise.mode,
          correct: atom != newAtoms.first,
          attempt: 1,
          fastEnough: true,
        ),
    ]);
    expect(progress.keys, containsAll(exercise.resultAtoms.map((a) => a.id)));
    expect(progress[newAtoms.first.id]!.totalErrors, 1);
  });
}
