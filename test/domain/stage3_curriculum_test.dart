// Защищает порядок после алфавита: сначала огласовки на отдельных буквах,
// затем связки нескольких букв и только после них короткие слова.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/lesson_explanation_queue.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stages = [
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
  ];
  final curriculum = CurriculumLoader.merge(stages);

  CurriculumContext contextWith(Iterable<String> known) => CurriculumContext(
    progress: {
      for (final id in known) id: const AtomProgress(state: AtomState.known),
    },
    formsByLetter: curriculum.formsByLetter,
  );

  test('огласовки ждут все буквы и их отдельные формы', () {
    final known = stages[0].nodes.map((n) => n.atom.id).toSet();
    final intro = stages[2].topics.first;
    expect(intro.requirement.isMet(contextWith(known)), isTrue);
    expect(known, isNot(contains('syl.ba_ta')));
    known.remove('ya.medial');
    expect(intro.requirement.isMet(contextWith(known)), isFalse);
  });

  test('связки открываются только после огласовок на отдельных буквах', () {
    final known = {
      for (final node in stages[0].nodes) node.atom.id,
      for (final node in stages[2].nodes)
        if (node.atom.kind != AtomKind.word) node.atom.id,
    };
    final connections = stages[1].topics.first;
    expect(connections.requirement.isMet(contextWith(known)), isTrue);
    known.remove('vowel.nun.fatha');
    expect(connections.requirement.isMet(contextWith(known)), isFalse);
  });

  test('темы идут: огласовки, связки, короткие слова', () {
    expect(
      curriculum.topics.where((topic) => topic.stage > 1).map((t) => t.id),
      [
        ...stages[2].topics
            .where((topic) => topic.stage == 2)
            .map((topic) => topic.id),
        ...stages[1].topics.map((topic) => topic.id),
        ...stages[2].topics
            .where((topic) => topic.stage == 3)
            .map((topic) => topic.id),
      ],
    );
  });

  test('42 обязательных слога покрывают все буквы и особые случаи', () {
    final stage = stages[2];
    final syllables = stage.nodes
        .map((n) => n.atom)
        .where((a) => a.kind == AtomKind.syllable)
        .toList();
    expect(syllables, hasLength(42));
    expect(syllables.map((a) => a.letterId).toSet(), hasLength(28));
    expect(syllables.take(3).map((a) => a.display), ['بَ', 'بِ', 'بُ']);
    final byId = {for (final atom in syllables) atom.id: atom};
    expect(byId['vowel.alif.fatha']?.display, 'أَ');
    expect(byId['vowel.alif.kasra']?.display, 'إِ');
    expect(byId['vowel.alif.damma']?.display, 'أُ');
    for (final letter in [
      'kha',
      'sod',
      'dod',
      'to',
      'zho',
      'ghayn',
      'qof',
      'ra',
    ]) {
      expect(byId, contains('vowel.$letter.fatha'));
      expect(byId, contains('vowel.$letter.kasra'));
    }
    expect(byId, isNot(contains('vowel.ra.damma')));
    expect(byId, contains('vowel.mim.kasra'));
    expect(byId, contains('vowel.ayn.kasra'));
    final groups = stage.topics.where(
      (topic) => topic.id.startsWith('m.haraka.group'),
    );
    expect(groups, hasLength(8));
    expect(groups.every((topic) => topic.counterOf.length <= 5), isTrue);
    expect(
      groups.expand((topic) => topic.counterOf),
      unorderedEquals(syllables.skip(3).map((atom) => atom.id)),
    );
    for (final variant in ['above', 'below']) {
      expect(
        File('assets/svg/alphabet/alif_hamza_${variant}_base.svg').existsSync(),
        isTrue,
      );
    }
    expect(
      syllables.every(
        (a) =>
            a.audioAsset != null &&
            a.tracing != null &&
            File('assets/svg/${a.tracing}.svg').existsSync() &&
            (a.audioAsset!.startsWith('tts:') ||
                File('assets/${a.audioAsset}').existsSync()),
      ),
      isTrue,
    );
    final harakat = stage.nodes
        .map((n) => n.atom)
        .where((a) => a.kind == AtomKind.haraka);
    expect(
      harakat.every(
        (a) =>
            a.tracing != null &&
            File('assets/svg/${a.tracing}.svg').existsSync(),
      ),
      isTrue,
    );
    expect(stage.topics[1].counterOf, [
      'haraka.fatha',
      'haraka.kasra',
      'haraka.damma',
    ]);
    expect(stage.topics[2].counterOf, [
      'vowel.ba.fatha',
      'vowel.ba.kasra',
      'vowel.ba.damma',
    ]);
  });

  test('слова открываются после обязательных слогов и связок', () {
    final stage = stages[2];
    final firstWords = stage.topics.firstWhere(
      (t) => t.id == 'm.haraka.words1',
    );
    final known = {
      for (final node in stages.take(2).expand((s) => s.nodes)) node.atom.id,
      for (final node in stage.nodes)
        if (node.atom.kind == AtomKind.syllable) node.atom.id,
    };
    expect(firstWords.requirement.isMet(contextWith(known)), isTrue);
    known.remove('syl.waw_ba');
    expect(firstWords.requirement.isMet(contextWith(known)), isFalse);
    known.add('syl.waw_ba');
    known.remove('vowel.ya.damma');
    expect(firstWords.requirement.isMet(contextWith(known)), isFalse);
    expect(
      TopicBoard(
        curriculum,
      ).missingHint(firstWords.requirement, contextWith(known)),
      contains('Йа с даммой'),
    );
    final words = stage.nodes
        .map((n) => n.atom)
        .where((a) => a.kind == AtomKind.word)
        .toList();
    expect(words, hasLength(9));
    expect(words.every((a) => a.audioAsset == 'tts:${a.display}'), isTrue);
    expect(
      words.every((a) => !a.display.contains(RegExp('[ًٌٍّْاوي]'))),
      isTrue,
    );
  });

  test('огласовки и слоги получают задания на слух, чтение и письмо', () {
    for (final kind in [AtomKind.haraka, AtomKind.syllable, AtomKind.word]) {
      final atoms = stages[2].nodes
          .map((n) => n.atom)
          .where((a) => a.kind == kind)
          .take(3)
          .toList();
      final plan = LessonPlan(
        template: LessonTemplate.newLetter,
        newAtoms: atoms,
        reviewAtoms: const [],
        reason: 'проверка огласовок',
      );
      final exercises = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(1),
      ).build(plan: plan, ctx: contextWith(const []), sessionId: 1);
      for (final atom in atoms) {
        final modes = exercises
            .where((e) => e.resultAtoms.contains(atom))
            .map((e) => e.mode)
            .toSet();
        expect(modes, contains(ExerciseMode.letterToSound));
        expect(
          modes.intersection({
            ExerciseMode.soundToLetter,
            ExerciseMode.harakaSequence,
          }),
          isNotEmpty,
          reason: 'Сборка тоже проверяет направление от звука к написанию',
        );
        if (kind == AtomKind.haraka) {
          expect(
            modes,
            containsAll([ExerciseMode.trace, ExerciseMode.traceFromMemory]),
          );
        }
        if (kind == AtomKind.syllable) {
          expect(modes, contains(ExerciseMode.drawHarakaForSound));
        }
      }
      final choices = exercises.where((exercise) => exercise.isChoice);
      expect(
        choices.every(
          (e) =>
              e.options.length ==
                  (e.mode == ExerciseMode.letterToSound ? 2 : 3) &&
              e.options.every((a) => a.kind == kind),
        ),
        isTrue,
      );
    }
  });

  test('новые слоги и слова объясняются рядом с первым заданием', () {
    final words = stages[2].topics.firstWhere((t) => t.id == 'm.haraka.words1');
    final atoms = words.counterOf
        .map((id) => curriculum.nodes.firstWhere((n) => n.atom.id == id).atom)
        .toList();
    final plan = LessonPlan(
      topicId: words.id,
      template: LessonTemplate.newLetter,
      newAtoms: atoms,
      reviewAtoms: const [],
      reason: 'первые слова',
    );
    final explanations = LessonExplanationQueue(curriculum);
    explanations.activate(plan, topicId: words.id);
    expect(explanations.introFor(plan, topicId: words.id), isEmpty);
    final exercise = ExerciseGenerator(
      curriculum: curriculum,
      random: Random(1),
    ).build(plan: plan, ctx: contextWith(const []), sessionId: 1).first;
    explanations.prepareFor(exercise);
    expect(explanations.card, isNotNull);
    expect(explanations.card!.kind, AtomKind.word);
  });

  test('все темы после алфавита достижимы в заданном порядке', () {
    final progress = {
      for (final node in stages[0].nodes)
        node.atom.id: const AtomProgress(state: AtomState.known, weak: true),
    };
    final planner = LessonPlanner(curriculum: curriculum);
    final expected = curriculum.topics
        .where((topic) => topic.stage > 1)
        .toList();
    for (var session = 1; session <= expected.length; session++) {
      final ctx = CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );
      final plan = planner.plan(
        ctx: ctx,
        sessionId: session,
        sessionsWithoutNew: 0,
      );
      expect(plan.topicId, expected[session - 1].id);
      final exercises = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(session),
      ).build(plan: plan, ctx: ctx, sessionId: session);
      expect(exercises.length, lessThanOrEqualTo(20));
      for (final atom in plan.newAtoms) {
        if (atom.kind != AtomKind.concept) {
          expect(exercises.any((e) => e.atom.id == atom.id), isTrue);
        }
        progress[atom.id] = AtomProgress(
          state: atom.kind == AtomKind.concept
              ? AtomState.introduced
              : AtomState.known,
          weak: atom.kind != AtomKind.concept,
        );
      }
    }
    final statuses = TopicBoard(curriculum).statuses(
      CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      ),
    );
    expect(
      statuses.where((s) => s.topic.stage > 1).every((s) => s.isDone),
      isTrue,
    );
  });

  test('правильные ответы действительно доводят курс до первых слов', () {
    var progress = {
      for (final node in stages[0].nodes)
        node.atom.id: const AtomProgress(state: AtomState.known, weak: true),
    };
    final planner = LessonPlanner(curriculum: curriculum);
    final fold = ProgressFold(letterFormIds: curriculum.letterFormIds);
    var reachedWords = false;
    var harakaLessons = 0;
    for (var number = 1; number <= 70; number++) {
      final ctx = CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );
      final plan = planner.plan(
        ctx: ctx,
        sessionId: number,
        sessionsWithoutNew: 0,
      );
      if (plan.topicId?.startsWith('m.haraka.') ?? false) {
        harakaLessons++;
      }
      if (plan.topicId == 'm.join') {
        // Изолированный планировщик считает вводное понятие и три знака
        // двумя шагами; экран объединяет их в одно занятие.
        expect(harakaLessons, lessThanOrEqualTo(11));
      }
      if (plan.topicId == 'm.haraka.words1') reachedWords = true;
      final exercises = ExerciseGenerator(
        curriculum: curriculum,
        random: Random(number),
      ).build(plan: plan, ctx: ctx, sessionId: number);
      final session = LessonSession(exercises: exercises, sessionId: number);
      while (!session.isFinished) {
        final exercise = session.current!;
        session.answer(exercise, exercise.answerIndex);
      }
      progress = fold.foldOnto(progress, [
        for (final atom in plan.newAtoms)
          AtomIntroduced(
            atomId: atom.id,
            sessionId: number,
            at: DateTime(2026, 9, 21).add(Duration(days: number)),
          ),
        ...session.log,
      ]);
      final statuses = TopicBoard(curriculum).statuses(
        CurriculumContext(
          progress: progress,
          formsByLetter: curriculum.formsByLetter,
        ),
      );
      if (statuses.where((s) => s.topic.stage > 1).every((s) => s.isDone)) {
        expect(reachedWords, isTrue);
        return;
      }
    }
    fail('Темы после алфавита не завершились за 70 занятий с верными ответами');
  });
}
