// Защищает порядок после алфавита: сначала огласовки на отдельных буквах,
// затем связки нескольких букв и только после них короткие слова.
// Выборочные огласовки сбалансированы, особые буквы покрыты полностью.
// Группы остаются темами, а их части не обходят практику или предел занятия.
// Ба вводится вместе со знаками; старые слоги ба не должны возвращать
// отдельный новый урок или блокировать переход к следующим разделам.
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/lesson_explanation_queue.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
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
      for (final topic in stages[2].topics.where((topic) => topic.stage == 2))
        ...topic.counterOf,
    };
    final connections = stages[1].topics.first;
    expect(connections.requirement.isMet(contextWith(known)), isTrue);
    expect(known, isNot(contains('vowel.ba.fatha')));
    known.remove('haraka.fatha');
    expect(connections.requirement.isMet(contextWith(known)), isFalse);
    known.add('haraka.fatha');
    for (final id in known.where((id) => id.startsWith('vowel.')).toList()) {
      known.remove(id);
      expect(
        connections.requirement.isMet(contextWith(known)),
        isFalse,
        reason: 'Связки не должны обходить $id',
      );
      known.add(id);
    }
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

  test('огласовки сбалансированы, группы сохранены, особые буквы покрыты', () {
    final stage = stages[2];
    final requiredIds = stage.topics
        .where((topic) => topic.stage == 2)
        .expand((topic) => topic.counterOf)
        .toSet();
    final requiredAtoms = stage.nodes
        .map((node) => node.atom)
        .where((atom) => requiredIds.contains(atom.id));
    final counts = [
      for (final mark in ['fatha', 'kasra', 'damma'])
        requiredAtoms.where((atom) => atom.tracing == 'harakat/$mark').length,
    ];
    expect(counts.toSet(), hasLength(1));
    expect(counts.first, greaterThan(0));
    expect(requiredAtoms.where((a) => a.kind == AtomKind.haraka), hasLength(3));
    expect(
      requiredAtoms.map((a) => a.letterId).whereType<String>().toSet(),
      hasLength(28),
    );
    expect(stage.topics.any((topic) => topic.id == 'm.haraka.ba'), isFalse);
    // Старые ID доступны для чтения истории и отладочных заданий.
    final syllables = stage.nodes
        .map((n) => n.atom)
        .where((a) => a.kind == AtomKind.syllable)
        .toList();
    expect(syllables.map((a) => a.letterId).toSet(), hasLength(28));
    expect(syllables.take(3).map((a) => a.display), ['بَ', 'بِ', 'بُ']);
    final byId = {for (final atom in syllables) atom.id: atom};
    expect(byId['vowel.alif.fatha']?.display, 'أَ');
    expect(byId['vowel.alif.kasra']?.display, 'إِ');
    expect(byId['vowel.alif.damma']?.display, 'أُ');
    for (final letter in [
      'ba',
      'alif',
      'ra',
      'sod',
      'dod',
      'to',
      'zho',
      'ghayn',
      'qof',
    ]) {
      for (final vowel in ['fatha', 'kasra', 'damma']) {
        final id = letter == 'ba' ? 'haraka.$vowel' : 'vowel.$letter.$vowel';
        expect(requiredIds, contains(id), reason: id);
      }
    }
    expect(requiredIds.where((id) => id.startsWith('vowel.kha.')), [
      'vowel.kha.fatha',
    ]);
    for (final atom in requiredAtoms) {
      expect(atom.explanationAsset, isNotNull, reason: atom.id);
      expect(
        File(atom.explanationAsset!).existsSync(),
        isTrue,
        reason: atom.id,
      );
    }
    final groups = stage.topics
        .where((topic) => topic.id.startsWith('m.haraka.group'))
        .toList();
    const lettersByGroup = [
      ['ta', 'kaf', 'dal', 'ra'],
      ['sin', 'mim', 'lam', 'shin'],
      ['ayn', 'jim', 'hha', 'fa'],
      ['nun', 'alif', 'tha'],
      ['kha', 'dhal', 'zay'],
      ['sod', 'dod', 'ha'],
      ['to', 'zho', 'waw'],
      ['ghayn', 'qof', 'ya'],
    ];
    expect(groups.length, lettersByGroup.length);
    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      expect(group.id, 'm.haraka.group${index + 1}');
      expect(
        group.counterOf.map((id) => byId[id]!.letterId).toSet(),
        lettersByGroup[index].toSet(),
      );
      final blocks = group.lessonBlocks.isEmpty
          ? [group.counterOf]
          : group.lessonBlocks;
      expect(blocks.expand((block) => block), group.counterOf);
      expect(blocks.every((block) => block.length <= 5), isTrue);
      final again = Topic.fromJson(group.toJson());
      expect(again.lessonBlocks, group.lessonBlocks);
    }
    expect(
      groups.expand((topic) => topic.counterOf),
      unorderedEquals(
        requiredAtoms
            .where((atom) => atom.kind == AtomKind.syllable)
            .map((atom) => atom.id),
      ),
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
      'vowel.ta.kasra',
      'vowel.kaf.fatha',
      'vowel.dal.damma',
      'vowel.ra.fatha',
      'vowel.ra.kasra',
      'vowel.ra.damma',
    ]);
  });

  test('старый прогресс слогов ба не задерживает первый перенос знаков', () {
    final firstGroup = stages[2].topics.firstWhere(
      (topic) => topic.id == 'm.haraka.group1',
    );
    for (final oldBaState in AtomState.values) {
      final progress = {
        for (final topic in curriculum.topics.takeWhile(
          (t) => t.id != firstGroup.id,
        ))
          for (final id in topic.counterOf)
            id: const AtomProgress(state: AtomState.known, weak: true),
        'vowel.ba.fatha': AtomProgress(state: oldBaState, totalErrors: 2),
      };
      final ctx = CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );
      expect(firstGroup.requirement.isMet(ctx), isTrue);
      final plan = LessonPlanner(
        curriculum: curriculum,
      ).plan(ctx: ctx, sessionId: 100, sessionsWithoutNew: 0);
      expect(plan.topicId, firstGroup.id);
      expect(plan.newAtoms.map((a) => a.letterId).toSet(), {
        'ta',
        'kaf',
        'dal',
      });
      expect(plan.reviewAtoms.any((id) => id.startsWith('vowel.ba.')), isFalse);
      expect(progress['vowel.ba.fatha']!.state, oldBaState);
      expect(progress['vowel.ba.fatha']!.totalErrors, 2);
    }
  });

  test('старый прогресс сохраняется, а новая дамма требует изучения', () {
    final topic = curriculum.topics.firstWhere(
      (topic) => topic.id == 'm.haraka.group1',
    );
    final progress = {
      for (final previous in curriculum.topics.takeWhile(
        (candidate) => candidate.id != topic.id,
      ))
        for (final id in previous.counterOf)
          id: const AtomProgress(state: AtomState.known, weak: true),
      for (final id in ['vowel.ta.fatha', 'vowel.kaf.fatha', 'vowel.dal.fatha'])
        id: const AtomProgress(state: AtomState.known, weak: true),
    };
    final ctx = CurriculumContext(
      progress: progress,
      formsByLetter: curriculum.formsByLetter,
    );
    final status = TopicBoard(curriculum)
        .statuses(ctx, completed: {topic.id: false})
        .firstWhere((status) => status.topic.id == topic.id);
    expect(status.isDone, isFalse);
    expect(status.done, 1);
    expect(ctx.stateOf('vowel.dal.damma'), AtomState.fresh);
    final plan = LessonPlanner(
      curriculum: curriculum,
    ).plan(ctx: ctx, sessionId: 100, sessionsWithoutNew: 0);
    expect(plan.topicId, topic.id);
    expect(plan.newAtoms.map((atom) => atom.id), [
      'vowel.ta.kasra',
      'vowel.dal.damma',
    ]);
    expect(progress['vowel.ta.fatha']!.state, AtomState.known);
    expect(progress['vowel.dal.fatha']!.state, AtomState.known);
  });

  test('части группы ждут практику и учитывают отключение произношения', () {
    final topic = curriculum.topics.firstWhere(
      (topic) => topic.id == 'm.haraka.group6',
    );
    final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
    final progress = {
      for (final previous in curriculum.topics.takeWhile(
        (previous) => previous.id != topic.id,
      ))
        for (final id in previous.counterOf)
          id: const AtomProgress(state: AtomState.known, weak: true),
      for (final id in topic.lessonBlocks.first)
        id: const AtomProgress(
          state: AtomState.known,
          successfulModes: {ExerciseMode.drawHarakaForSound},
        ),
    };
    CurriculumContext context() => CurriculumContext(
      progress: progress,
      formsByLetter: curriculum.formsByLetter,
    );
    final board = TopicBoard(curriculum);
    expect(board.lessonAtomIds(topic, context()), topic.lessonBlocks.first);
    expect(board.planFor(topic, context()).newAtoms, isEmpty);
    const withoutVoice = LearningRules(requirePronunciation: false);
    final nextPart = board.planFor(topic, context(), rules: withoutVoice);
    expect(nextPart.newAtoms.map((atom) => atom.id), topic.lessonBlocks.last);
    expect(
      TopicBoard(curriculum, rules: withoutVoice)
          .statuses(context())
          .firstWhere((status) => status.topic.id == topic.id)
          .isDone,
      isFalse,
    );
    for (final id in topic.lessonBlocks.first) {
      progress[id] = AtomProgress(
        state: AtomState.known,
        successfulModes: const LearningRules().requiredPracticeModes(byId[id]!),
      );
    }
    expect(board.lessonAtomIds(topic, context()), topic.lessonBlocks.last);
    for (final id in topic.lessonBlocks.last) {
      progress[id] = const AtomProgress(state: AtomState.known, weak: true);
    }
    final review = board.planFor(topic, context());
    expect(review.newAtoms, isEmpty);
    expect(review.reviewAtoms, topic.counterOf);
    final exercises = ExerciseGenerator(
      curriculum: curriculum,
    ).build(plan: review, ctx: context(), sessionId: 20);
    expect(exercises.length, lessThanOrEqualTo(20));
    expect(
      exercises
          .expand((exercise) => exercise.resultAtoms)
          .map((atom) => atom.id),
      containsAll(topic.counterOf),
    );
  });

  test('слова открываются после обязательных слогов и связок', () {
    final stage = stages[2];
    final firstWords = stage.topics.firstWhere(
      (t) => t.id == 'm.haraka.words1',
    );
    final known = {
      for (final node in stages.take(2).expand((s) => s.nodes)) node.atom.id,
      for (final topic in stage.topics.where((topic) => topic.stage == 2))
        ...topic.counterOf,
    };
    expect(firstWords.requirement.isMet(contextWith(known)), isTrue);
    expect(known, isNot(contains('vowel.ba.fatha')));
    known.remove('haraka.kasra');
    expect(firstWords.requirement.isMet(contextWith(known)), isFalse);
    known.add('haraka.kasra');
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
            ExerciseMode.harakaForLetters,
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
    for (var session = 1; session <= expected.length * 2; session++) {
      final ctx = CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );
      final plan = planner.plan(
        ctx: ctx,
        sessionId: session,
        sessionsWithoutNew: 0,
      );
      final next = TopicBoard(curriculum)
          .statuses(ctx)
          .where((status) => status.topic.stage > 1)
          .where((status) => !status.isDone)
          .firstOrNull;
      if (next == null) break;
      expect(plan.topicId, next.topic.id);
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
        expect(
          harakaLessons,
          lessThanOrEqualTo(
            stages[2].topics.where((topic) => topic.stage == 2).length * 2,
          ),
        );
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
