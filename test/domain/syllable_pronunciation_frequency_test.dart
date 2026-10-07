// Голос не должен исчезнуть за письмом, повториться при доборе одной сессии
// или заполнить повторение почти целиком. Предел огласовок — 15% занятия,
// включая добор: новые слоги и голосовые пробелы важнее уже освоенных.
// На отдельные буквы предел не переносится и их голосовой бюджет не расходуется.
// После отключения голоса письмо остаётся и тема завершается без сервера.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
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
  CurriculumContext before(Topic target) => CurriculumContext(
    progress: {
      for (final topic in curriculum.topics.takeWhile((t) => t.id != target.id))
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

  test('новые знаки и слоги получают приоритет в голосовом бюджете', () {
    for (final topic in curriculum.topics.where(
      (t) => t.id == 'm.haraka.signs' || t.id.startsWith('m.haraka.group'),
    )) {
      final ctx = before(topic);
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
      for (var seed = 0; seed < 20; seed++) {
        final tasks = ExerciseGenerator(
          curriculum: curriculum,
          random: Random(seed),
        ).build(plan: plan, ctx: ctx, sessionId: 100);
        expect(tasks.length, lessThanOrEqualTo(20), reason: topic.id);
        expect(
          tasks.where((task) => task.mode.isPronunciation).length,
          lessThanOrEqualTo(max(1, tasks.length * 15 ~/ 100)),
          reason: '${topic.id}, seed $seed',
        );
        final voiceAtoms = tasks
            .where((task) => task.mode.isPronunciation)
            .map((task) => task.atom)
            .toSet();
        expect(voiceAtoms, isNotEmpty, reason: '${topic.id}, seed $seed');
        expect(voiceAtoms.every(plan.newAtoms.contains), isTrue);
        for (final atom in plan.newAtoms.where(
          (a) => a.kind != AtomKind.concept,
        )) {
          final own = tasks.where((task) => task.atom == atom);
          final voice = own.where(
            (task) => task.mode == ExerciseMode.saySyllable,
          );
          expect(
            voice.length,
            lessThanOrEqualTo(1),
            reason: '${atom.id}, seed $seed',
          );
          for (final exercise in voice) {
            expect(exercise.isRequired, isTrue);
            expect(exercise.resultAtoms, [atom]);
            expect(exercise.mode.isActive, isTrue);
          }
          final modes = own.map((task) => task.mode).toSet();
          if (atom.kind == AtomKind.haraka) {
            expect(
              modes,
              containsAll([ExerciseMode.trace, ExerciseMode.traceFromMemory]),
            );
          } else {
            expect(modes, contains(ExerciseMode.drawHarakaForSound));
          }
        }
      }
    }
  });

  test('повторение двадцати слогов оставляет голосу только три места', () {
    final ctx = before(curriculum.topics.firstWhere((t) => t.id == 'm.join'));
    final atoms = byId.values
        .where((a) => a.id.startsWith('vowel.') && ctx.isKnown(a.id))
        .take(20)
        .toList();
    final plan = LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: atoms.map((a) => a.id).toList(),
      reviewCounts: {for (final a in atoms) a.id: 1},
      reason: 'повтор',
    );
    final voicedIds = <String>{};
    for (var seed = 0; seed < 20; seed++) {
      final tasks = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(seed),
      ).build(plan: plan, ctx: ctx, sessionId: 100);
      expect(tasks, hasLength(20));
      final voice = tasks.where((task) => task.mode.isPronunciation);
      expect(voice, hasLength(3));
      voicedIds.addAll(voice.map((task) => task.atom.id));
      final counts = {
        for (final mode in [
          ExerciseMode.soundToLetter,
          ExerciseMode.letterToSound,
          ExerciseMode.syllableBuild,
        ])
          mode: tasks.where((task) => task.mode == mode).length,
      };
      expect(counts.values, everyElement(greaterThanOrEqualTo(3)));
      final sortedCounts = counts.values.sortedBy((count) => count);
      expect(sortedCounts.last - sortedCounts.first, lessThanOrEqualTo(1));
    }
    // Выбор не должен навсегда закрепить голос за первыми тремя в списке.
    expect(voicedIds.length, greaterThan(3));
    final continued = ExerciseGenerator(curriculum: curriculum).build(
      plan: plan,
      ctx: ctx,
      sessionId: 100,
      previousPronunciations: atoms.map((a) => a.id).toSet(),
    );
    expect(continued.where((task) => task.mode.isPronunciation), isEmpty);
  });

  test('два блока одной сессии делят три голосовых места', () {
    final ctx = before(curriculum.topics.firstWhere((t) => t.id == 'm.join'));
    final atoms = byId.values
        .where((a) => a.id.startsWith('vowel.') && ctx.isKnown(a.id))
        .take(20)
        .toList();
    LessonPlan review(List<Atom> targets) => LessonPlan(
      template: LessonTemplate.review,
      newAtoms: const [],
      reviewAtoms: targets.map((atom) => atom.id).toList(),
      reviewCounts: {for (final atom in targets) atom.id: 1},
      reason: 'добор',
    );
    final first = ExerciseGenerator(curriculum: curriculum).build(
      plan: review(atoms.take(8).toList()),
      ctx: ctx,
      sessionId: 100,
      taskLimit: 8,
    );
    final firstVoice = first.where((task) => task.mode.isPronunciation);
    expect(firstVoice, hasLength(1));
    final next = ExerciseGenerator(curriculum: curriculum).build(
      plan: review(atoms.skip(8).toList()),
      ctx: ctx,
      sessionId: 100,
      taskLimit: 12,
      previousTaskCount: first.length,
      previousFormSequences: first
          .where((task) => task.isFormMaintenance)
          .map((task) => task.atom.letterId!)
          .toSet(),
      previousPronunciations: firstVoice.map((task) => task.atom.id).toSet(),
    );
    expect(next.where((task) => task.mode.isPronunciation), hasLength(2));
    expect(first.length + next.length, 20);
  });

  test('голосовые пробелы не превращают короткий добор в диктовку', () {
    final fullCtx = before(
      curriculum.topics.firstWhere((t) => t.id == 'm.join'),
    );
    final atoms = byId.values
        .where((a) => a.id.startsWith('vowel.') && fullCtx.isKnown(a.id))
        .take(8)
        .toList();
    final ctx = CurriculumContext(
      progress: {
        ...fullCtx.progress,
        for (final atom in atoms)
          atom.id: const AtomProgress(
            state: AtomState.known,
            successfulModes: {ExerciseMode.drawHarakaForSound},
          ),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    final tasks = ExerciseGenerator(curriculum: curriculum).build(
      plan: LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: atoms.map((atom) => atom.id).toList(),
        reviewCounts: {for (final atom in atoms) atom.id: 1},
        reason: 'недостаёт голоса',
      ),
      ctx: ctx,
      sessionId: 100,
    );
    expect(tasks.where((task) => !task.isFormMaintenance), hasLength(8));
    expect(tasks.where((task) => task.mode.isPronunciation), hasLength(1));
  });

  test('голосовой пробел выбирается раньше уже пройденного произношения', () {
    final fullCtx = before(
      curriculum.topics.firstWhere((t) => t.id == 'm.join'),
    );
    final atoms = byId.values
        .where(
          (atom) => atom.id.startsWith('vowel.') && fullCtx.isKnown(atom.id),
        )
        .take(20)
        .toList();
    final missingIds = atoms.skip(18).map((atom) => atom.id).toSet();
    final ctx = CurriculumContext(
      progress: {
        ...fullCtx.progress,
        for (final id in missingIds)
          id: const AtomProgress(
            state: AtomState.known,
            successfulModes: {ExerciseMode.drawHarakaForSound},
          ),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    for (var seed = 0; seed < 10; seed++) {
      final tasks =
          ExerciseGenerator(curriculum: curriculum, random: Random(seed)).build(
            plan: LessonPlan(
              template: LessonTemplate.review,
              newAtoms: const [],
              reviewAtoms: atoms.map((atom) => atom.id).toList(),
              reviewCounts: {for (final atom in atoms) atom.id: 1},
              reason: 'два голосовых пробела',
            ),
            ctx: ctx,
            sessionId: 100,
          );
      final voice = tasks.where((task) => task.mode.isPronunciation);
      expect(voice, hasLength(3));
      expect(
        voice.map((task) => task.atom.id).toSet(),
        containsAll(missingIds),
      );
    }
  });

  test('отдельные буквы сохраняют голос по прежним правилам', () {
    final fullCtx = before(
      curriculum.topics.firstWhere((t) => t.id == 'm.join'),
    );
    final atoms = byId.values
        .where((atom) => atom.form == LetterForm.isolated)
        .take(20)
        .toList();
    final ctx = CurriculumContext(
      progress: {
        ...fullCtx.progress,
        for (final atom in atoms)
          atom.id: fullCtx.progress[atom.id]!.copyWith(
            modesInStreak: {
              ExerciseMode.soundToLetter,
              ExerciseMode.traceFromMemory,
            },
          ),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    for (final rules in [
      const LearningRules(),
      const LearningRules(syllablePronunciationMaxPercent: 0),
    ]) {
      final tasks = ExerciseGenerator(curriculum: curriculum, rules: rules)
          .build(
            plan: LessonPlan(
              template: LessonTemplate.review,
              newAtoms: const [],
              reviewAtoms: atoms.map((atom) => atom.id).toList(),
              reviewCounts: {for (final atom in atoms) atom.id: 1},
              reason: 'повтор букв',
            ),
            ctx: ctx,
            sessionId: 100,
          );
      expect(tasks, hasLength(20));
      expect(
        tasks.where((task) => task.mode == ExerciseMode.sayName),
        hasLength(20),
      );
    }
  });

  test('произнесённые буквы не расходуют голосовой предел огласовок', () {
    final ctx = before(curriculum.topics.firstWhere((t) => t.id == 'm.join'));
    final syllables = byId.values
        .where((atom) => atom.id.startsWith('vowel.') && ctx.isKnown(atom.id))
        .take(16)
        .toList();
    final previousLetters = byId.values
        .where((atom) => atom.form == LetterForm.isolated)
        .take(4)
        .map((atom) => atom.id)
        .toSet();
    final tasks = ExerciseGenerator(curriculum: curriculum).build(
      plan: LessonPlan(
        template: LessonTemplate.review,
        newAtoms: const [],
        reviewAtoms: syllables.map((atom) => atom.id).toList(),
        reviewCounts: {for (final atom in syllables) atom.id: 1},
        reason: 'огласовки после четырёх букв',
      ),
      ctx: ctx,
      sessionId: 100,
      taskLimit: 16,
      previousTaskCount: 4,
      previousPronunciations: previousLetters,
    );
    expect(tasks, hasLength(16));
    expect(
      tasks.where((task) => task.mode == ExerciseMode.saySyllable),
      hasLength(3),
    );
  });

  test(
    'техническое отключение сохраняет письмо и снимает голосовой критерий',
    () {
      final topic = curriculum.topics.firstWhere(
        (t) => t.id == 'm.haraka.group1',
      );
      final ctx = before(topic);
      final plan = TopicBoard(curriculum).planFor(topic, ctx, sessionId: 100);
      final tasks = ExerciseGenerator(curriculum: curriculum).build(
        plan: plan,
        ctx: ctx,
        sessionId: 100,
        unavailableModes: const {ExerciseMode.saySyllable},
      );
      expect(tasks.where((task) => task.mode.isPronunciation), isEmpty);
      for (final atom in plan.newAtoms) {
        expect(
          tasks.where((task) => task.atom == atom).map((task) => task.mode),
          contains(ExerciseMode.drawHarakaForSound),
        );
        const known = AtomProgress(
          state: AtomState.known,
          successfulModes: {ExerciseMode.drawHarakaForSound},
        );
        expect(
          const LearningRules()
              .requiredPracticeModes(atom)
              .difference(known.successfulModes),
          {ExerciseMode.saySyllable},
        );
        expect(
          const LearningRules(
            requirePronunciation: false,
          ).requiredPracticeModes(atom).difference(known.successfulModes),
          isEmpty,
        );
      }
    },
  );
}
