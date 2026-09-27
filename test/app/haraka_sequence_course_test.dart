// Защищает включение звуковой сборки в курс: она не сокращает занятие,
// появляется только после знакомства с тремя слогами и пишет отдельный
// результат каждому слогу, включая частично верную раскладку.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_exercise_presentation.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:collection/collection.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final curriculum = CurriculumLoader.merge([
    for (final stage in [1, 2, 3])
      CurriculumLoader.parse(
        File('assets/curriculum/stage$stage.json').readAsStringSync(),
      ),
  ]);
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};
  final ba = [
    byId['vowel.ba.fatha']!,
    byId['vowel.ba.kasra']!,
    byId['vowel.ba.damma']!,
  ];

  LessonPlan planFor(List<Atom> atoms) => LessonPlan(
    template: LessonTemplate.newLetter,
    newAtoms: atoms,
    reviewAtoms: const [],
    reason: 'проверка сборки огласовок',
  );

  CurriculumContext emptyContext() => CurriculumContext(
    progress: const {},
    formsByLetter: curriculum.formsByLetter,
  );

  test('в полном блоке количество заданий не падает', () {
    final group = [
      ...ba,
      for (final sign in ['fatha', 'kasra', 'damma']) byId['vowel.alif.$sign']!,
    ];
    final generator = ExerciseGenerator(
      curriculum: curriculum,
      random: Random(7),
    );
    final plan = planFor(group);
    final withSequences = generator.build(
      plan: plan,
      ctx: emptyContext(),
      sessionId: 1,
    );
    final withoutSequences =
        ExerciseGenerator(curriculum: curriculum, random: Random(7)).build(
          plan: plan,
          ctx: emptyContext(),
          sessionId: 1,
          previousHarakaSequences: {'ba', 'alif'},
        );
    expect(withSequences, hasLength(withoutSequences.length));
    expect(withSequences, hasLength(20));
    expect(
      withSequences.where((e) => e.mode == ExerciseMode.harakaSequence),
      hasLength(2),
    );
    for (final atom in group) {
      final modes = withSequences
          .where((e) => e.resultAtoms.contains(atom))
          .map((e) => e.mode)
          .toSet();
      expect(modes, contains(ExerciseMode.harakaSequence));
      expect(modes, contains(ExerciseMode.letterToSound));
    }
  });

  test('неполная тройка не даёт сборку', () {
    final exercises =
        ExerciseGenerator(curriculum: curriculum, random: Random(4)).build(
          plan: planFor([ba[0], ba[1], byId['vowel.ta.fatha']!]),
          ctx: emptyContext(),
          sessionId: 1,
        );
    expect(
      exercises.where((e) => e.mode == ExerciseMode.harakaSequence),
      isEmpty,
    );
  });

  test('недорисованный слог не закрывается одной раскладкой', () {
    // Пять новых слогов обычно успевают получить рисунок в первом занятии.
    // Но прерванное задание или старый прогресс всё ещё требуют добора.
    final topic = curriculum.topics.firstWhere(
      (topic) => topic.id == 'm.haraka.group1',
    );
    final group = topic.counterOf.map((id) => byId[id]!).toList();
    final review = [...ba, byId['haraka.fatha']!];
    final before = CurriculumContext(
      progress: {
        for (final atom in review)
          atom.id: const AtomProgress(state: AtomState.known),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    final firstLesson =
        ExerciseGenerator(curriculum: curriculum, random: Random(7)).build(
          plan: LessonPlan(
            topicId: topic.id,
            template: LessonTemplate.newLetter,
            newAtoms: group,
            reviewAtoms: const [],
            spacedReview: review.map((atom) => atom.id).toList(),
            reason: 'полный блок с повторением',
          ),
          ctx: before,
          sessionId: 1,
        );
    expect(firstLesson, hasLength(20));
    final successfulModes = {
      for (final atom in group)
        atom.id: firstLesson
            .where((exercise) => exercise.resultAtoms.contains(atom))
            .map((exercise) => exercise.mode)
            .toSet(),
    };
    expect(
      group.every(
        (atom) =>
            successfulModes[atom.id]!.contains(ExerciseMode.drawHarakaForSound),
      ),
      isTrue,
    );
    successfulModes[group.first.id]!.remove(ExerciseMode.drawHarakaForSound);
    final withoutDrawing = group
        .where(
          (atom) => !successfulModes[atom.id]!.contains(
            ExerciseMode.drawHarakaForSound,
          ),
        )
        .toList();
    expect(withoutDrawing, isNotEmpty);

    final after = CurriculumContext(
      progress: {
        ...before.progress,
        for (final atom in group)
          atom.id: AtomProgress(
            state: AtomState.known,
            successfulModes: successfulModes[atom.id]!,
          ),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    final board = TopicBoard(curriculum);
    expect(
      board.statuses(after).firstWhere((s) => s.topic.id == topic.id).isDone,
      isFalse,
    );
    final followUp = LessonPlanner(curriculum: curriculum).plan(
      ctx: after,
      sessionId: 2,
      sessionsWithoutNew: 0,
      topicIds: {topic.id},
    );
    expect(followUp.isFocusedReview, isTrue);
    expect(followUp.reviewAtoms.toSet(), {
      for (final atom in withoutDrawing) atom.id,
    });
    final exercises = ExerciseGenerator(
      curriculum: curriculum,
    ).build(plan: followUp, ctx: after, sessionId: 2);
    expect(
      exercises
          .where((e) => e.mode == ExerciseMode.drawHarakaForSound)
          .map((e) => e.atom.id)
          .toSet(),
      followUp.reviewAtoms.toSet(),
    );

    // В тот же день темп сначала даёт смешанный повтор. Он тоже не теряет
    // недорисованные слоги, поэтому их не приходится ждать до завтра.
    final paced = LessonPlanner(curriculum: curriculum).plan(
      ctx: after,
      sessionId: 2,
      sessionsWithoutNew: 0,
      topicIds: {topic.id},
      pacing: const PacingSnapshot(enabled: true, hasNewMaterialToday: true),
    );
    final pacedExercises = ExerciseGenerator(
      curriculum: curriculum,
    ).build(plan: paced, ctx: after, sessionId: 2);
    expect(
      pacedExercises
          .where((e) => e.mode == ExerciseMode.drawHarakaForSound)
          .map((e) => e.atom.id)
          .toSet(),
      containsAll(withoutDrawing.map((atom) => atom.id)),
    );
  });

  test('частично верная сборка пишет три независимых результата', () async {
    final database = ProgressDatabase(NativeDatabase.memory());
    final audio = _RecordingAudio();
    addTearDown(database.close);
    final controller = LessonController(
      database: database,
      curriculum: curriculum,
      plan: planFor(ba),
      audio: audio,
      shapeLoader: (_) async =>
          throw UnsupportedError('Холст не нужен до звуковой сборки'),
    );
    addTearDown(controller.onClose);
    final ready = Completer<void>();
    final subscription = controller.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) {
        ready.complete();
      }
    });
    controller.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    expect(controller.loadError.value, isNull);
    expect(controller.totalExercises, 15);

    var steps = 0;
    while (controller.current?.mode != ExerciseMode.harakaSequence) {
      expect(++steps, lessThan(20));
      while (controller.card.value != null) {
        await controller.dismissCard();
      }
      await controller.answerCorrectly(advance: true);
    }
    while (controller.card.value != null) {
      await controller.dismissCard();
    }
    final exercise = controller.current!;
    final presentation = LessonExercisePresentation.from(exercise);
    expect(presentation.input, LessonInputKind.formSequence);
    expect(presentation.question, LessonQuestionKind.harakaSequence);
    expect(exercise.sequenceOrder, hasLength(3));
    expect(exercise.sequenceOrder.map((atom) => atom.id).toSet(), {
      for (final atom in ba) atom.id,
    });
    controller.startSequenceSlot(exercise, 0);
    await Future<void>.delayed(Duration.zero);
    expect(audio.played.last, exercise.sequenceOrder.first.audioAsset);
    expect(controller.sequencePlayingSlot.value, 0);
    await controller.playSequenceSlot(exercise, 0);
    expect(controller.sequencePlayingSlot.value, isNull);
    await controller.playSequenceSlot(exercise, 1);
    expect(audio.played.last, exercise.sequenceOrder[1].audioAsset);
    final placed = [...exercise.sequenceOrder]..swap(1, 2);
    await controller.submitFormSequence(placed);

    final events = (await database.readAll())
        .whereType<ProgressEvent>()
        .where((event) => event.mode == ExerciseMode.harakaSequence)
        .toList();
    expect(events, hasLength(3));
    expect(
      events.singleWhere((e) => e.atomId == placed.first.id).correct,
      isTrue,
    );
    expect(events.where((e) => !e.correct), hasLength(2));
    expect(controller.formSequenceSlotResults, [true, false, false]);
    expect(controller.formSequenceInitialPlaced, [placed.first, null, null]);

    await controller.submit();
    await controller.submitFormSequence(exercise.sequenceOrder);
    final corrected = (await database.readAll())
        .whereType<ProgressEvent>()
        .where((event) => event.mode == ExerciseMode.harakaSequence)
        .toList();
    expect(corrected, hasLength(6));
    expect(corrected.skip(3).every((event) => event.correct), isTrue);
    expect(corrected.skip(3).every((event) => event.attempt == 2), isTrue);
  });
}

class _RecordingAudio implements LessonAudio {
  @override
  final ValueNotifier<AudioTrack> track = ValueNotifier(AudioTrack.silent);

  final played = <String>[];

  @override
  Future<void> playAsset(String? asset) async {
    if (asset == null) return;
    played.add(asset);
    track.value = const AudioTrack(isPlaying: true);
  }

  @override
  Future<void> toggleAsset(String? asset) => playAsset(asset);

  @override
  Future<void> stop() async => track.value = AudioTrack.silent;

  @override
  Future<void> dispose() async => track.dispose();
}
