// Профиль выбирается контентом, а не типом или разделом. Эти проверки
// защищают настройку будущих атомов, загрузку ошибочных профилей и пределы
// короткой практики, включая пересборку занятия и отключение голоса.
import 'dart:convert';
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
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curriculum = CurriculumLoader.merge([
    for (final asset in CurriculumLoader.defaultAssets)
      CurriculumLoader.parse(File(asset).readAsStringSync()),
  ]);
  const rules = LearningRules();
  final byId = {for (final node in curriculum.nodes) node.atom.id: node.atom};

  Map<String, AtomProgress> before(Topic topic) => {
    for (final previous in curriculum.topics.takeWhile((t) => t != topic))
      for (final id in previous.counterOf)
        id: AtomProgress(
          state: byId[id]!.kind == AtomKind.concept
              ? AtomState.introduced
              : AtomState.known,
          cleanStreak: 3,
          successfulModes: rules.requiredPracticeModes(byId[id]!),
        ),
  };

  CurriculumContext context(Map<String, AtomProgress> progress) =>
      CurriculumContext(
        progress: progress,
        formsByLetter: curriculum.formsByLetter,
      );

  test(
    'короткий профиль назначен только словам, прежний материал стандартный',
    () {
      for (final node in curriculum.nodes) {
        expect(
          node.atom.practiceProfile.isStandard,
          node.atom.kind != AtomKind.word,
          reason: node.atom.id,
        );
      }
      final roundTrip = CurriculumLoader.merge([
        CurriculumLoader.parse(jsonEncode(curriculum.toJson())),
      ]);
      for (final node in roundTrip.nodes) {
        expect(
          node.atom.practiceProfile.isStandard,
          byId[node.atom.id]!.practiceProfile.isStandard,
        );
      }
    },
  );

  test('новому слову дают сборку и выбор; голос их не вытесняет', () {
    for (final topic in curriculum.topics.where((t) => t.stage == 3)) {
      for (final voiceEnabled in [true, false]) {
        final activeRules = rules.copyWith(requirePronunciation: voiceEnabled);
        final ctx = context(before(topic));
        final plan = TopicBoard(
          curriculum,
        ).planFor(topic, ctx, sessionId: 100, rules: activeRules);
        final tasks = ExerciseGenerator(
          curriculum: curriculum,
          rules: activeRules,
          random: Random(12),
        ).build(plan: plan, ctx: ctx, sessionId: 100);
        final voices = tasks.where((task) => task.mode.isPronunciation).length;
        expect(voices, lessThanOrEqualTo(max(1, tasks.length * 15 ~/ 100)));
        expect(tasks.length, lessThanOrEqualTo(20));
        expect(
          tasks.map((task) => task.atom.id).toSet().length,
          lessThanOrEqualTo(8),
        );
        for (final atom in plan.newAtoms.where(
          (a) => a.kind == AtomKind.word,
        )) {
          final own = tasks.where((task) => task.atom == atom).toList();
          expect(
            own
                .where((task) => !task.mode.isPronunciation)
                .map((task) => task.mode),
            [ExerciseMode.wordBuild, ExerciseMode.soundToLetter],
          );
          expect(own.length, lessThanOrEqualTo(3));
          if (!voiceEnabled) expect(own.length, 2);
        }
      }
    }
  });

  test('повтор освоенных слов сохраняет короткие форматы и общий предел', () {
    final progress = {
      for (final node in curriculum.nodes)
        node.atom.id: AtomProgress(
          state: AtomState.known,
          cleanStreak: 3,
          successfulModes: rules.requiredPracticeModes(node.atom),
        ),
    };
    final ctx = context(progress);
    final plan = LessonPlanner(
      curriculum: curriculum,
    ).plan(ctx: ctx, sessionId: 100, sessionsWithoutNew: 0);
    final tasks = ExerciseGenerator(
      curriculum: curriculum,
      random: Random(13),
    ).build(plan: plan, ctx: ctx, sessionId: 100);
    expect(tasks, isNotEmpty);
    expect(tasks.every((task) => task.atom.kind == AtomKind.word), isTrue);
    expect(
      tasks.map((task) => task.mode),
      isNot(contains(ExerciseMode.wordBuild)),
    );
    for (final id in tasks.map((task) => task.atom.id).toSet()) {
      expect(
        tasks.where((task) => task.atom.id == id).length,
        lessThanOrEqualTo(3),
      );
    }
  });

  test(
    'профиль работает для новых знаков и соседствует со стандартными атомами',
    () {
      final loaded = CurriculumLoader.merge([
        CurriculumLoader.parse(
          jsonEncode({
            'practiceProfiles': {
              'briefSigns': {
                'plannedExercises': 2,
                'maxExercisesPerSession': 2,
                'initialModes': ['nameToForm', 'formToName'],
                'reviewModes': ['formToName', 'nameToForm'],
              },
            },
            'nodes': [
              for (var i = 0; i < 3; i++)
                {
                  'atom': {
                    'id': 'future.$i',
                    'kind': 'sign',
                    'display': '$i',
                    'practiceProfileId': i == 2 ? 'standard' : 'briefSigns',
                  },
                  'requirement': {'type': 'always'},
                },
            ],
          }),
        ),
      ]);
      final atoms = loaded.nodes.map((node) => node.atom).toList();
      final ctx = CurriculumContext(progress: {}, formsByLetter: {});
      final tasks = ExerciseGenerator(curriculum: loaded, random: Random(4))
          .build(
            plan: LessonPlan(
              template: LessonTemplate.newLetter,
              newAtoms: atoms,
              reviewAtoms: [],
              reason: 'будущий материал',
            ),
            ctx: ctx,
            sessionId: 1,
          );
      for (final atom in atoms.take(2)) {
        expect(
          tasks.where((task) => task.atom == atom).map((task) => task.mode),
          [ExerciseMode.nameToForm, ExerciseMode.formToName],
        );
      }
      expect(tasks.where((task) => task.atom == atoms.last).length, 5);
    },
  );

  test(
    'неизвестный профиль и неподдерживаемая обязательная практика отвергаются',
    () {
      Curriculum content(String profile, Map<String, Object?> settings) =>
          CurriculumLoader.parse(
            jsonEncode({
              'practiceProfiles': {'brief': settings},
              'nodes': [
                {
                  'atom': {
                    'id': 'future',
                    'kind': 'sign',
                    'practiceProfileId': profile,
                  },
                  'requirement': {'type': 'always'},
                },
              ],
            }),
          );
      const good = {
        'initialModes': ['nameToForm'],
        'reviewModes': ['formToName'],
      };
      expect(
        () => CurriculumLoader.merge([content('missing', good)]),
        throwsStateError,
      );
      expect(
        () => CurriculumLoader.merge([
          content('brief', {
            ...good,
            'initialModes': ['wordBuild'],
            'requiredModes': ['wordBuild'],
          }),
        ]),
        throwsStateError,
      );
      expect(
        () => CurriculumLoader.merge([
          content('brief', {
            ...good,
            'plannedExercises': 4,
            'maxExercisesPerSession': 2,
          }),
        ]),
        throwsStateError,
      );
      expect(
        () => CurriculumLoader.merge([
          content('brief', good),
          content('brief', good),
        ]),
        throwsStateError,
      );
    },
  );
}
