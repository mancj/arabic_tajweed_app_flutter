import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/exercise_generator.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/lesson_session.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Прогон курса насквозь: идеальный ученик отвечает всё верно и быстро.
/// Тест ловит тупики в графе — ситуацию, когда планировщику нечего выдать,
/// а курс при этом не пройден.
void main() {
  const rules = LearningRules();
  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );

  Map<String, List<String>> formsByLetter() {
    final result = <String, List<String>>{};
    for (final node in curriculum.nodes) {
      final letterId = node.atom.letterId;
      if (letterId == null) continue;
      (result[letterId] ??= []).add(node.atom.id);
    }
    return result;
  }

  ({Map<String, AtomProgress> progress, int lessons, int stalled}) walk(
    int lessons,
  ) {
    final fold = const ProgressFold(rules: rules);
    var progress = <String, AtomProgress>{};
    var sessionsWithoutNew = 0;
    var stalled = 0;
    var day = DateTime(2026, 1, 1);

    for (var session = 1; session <= lessons; session++) {
      final ctx = CurriculumContext(
        progress: progress,
        formsByLetter: formsByLetter(),
      );
      final plan = LessonPlanner(curriculum: curriculum, rules: rules).plan(
        ctx: ctx,
        sessionId: session,
        sessionsWithoutNew: sessionsWithoutNew,
      );

      final log = <LogEntry>[
        for (final atom in plan.newAtoms)
          AtomIntroduced(atomId: atom.id, sessionId: session, at: day),
      ];
      progress = fold.foldOnto(progress, log);
      sessionsWithoutNew = plan.newAtoms.isEmpty ? sessionsWithoutNew + 1 : 0;

      final exercises =
          ExerciseGenerator(
            curriculum: curriculum,
            rules: rules,
            random: Random(session),
          ).build(
            plan: plan,
            ctx: CurriculumContext(
              progress: progress,
              formsByLetter: formsByLetter(),
            ),
            sessionId: session,
          );

      if (exercises.isEmpty && plan.newAtoms.isEmpty) stalled++;

      final lesson = LessonSession(
        exercises: exercises,
        sessionId: session,
        rules: rules,
        now: () => day,
      );
      while (!lesson.isFinished) {
        final e = lesson.current!;
        lesson.answer(e, e.answerIndex, fastEnough: true);
      }
      progress = fold.foldOnto(progress, lesson.log);

      // Каждый урок — новый день, иначе интервалы подтверждения не идут.
      day = day.add(const Duration(days: 1));
    }

    return (progress: progress, lessons: lessons, stalled: stalled);
  }

  test('курс не упирается в тупик за 30 уроков', () {
    final result = walk(30);
    expect(
      result.stalled,
      0,
      reason: 'нашлись уроки, где нечего вводить и нечего спрашивать',
    );
  });

  test('идеальный ученик доводит буквы до known', () {
    final progress = walk(30).progress;
    final known = progress.entries
        .where((e) => e.value.state.index >= AtomState.known.index)
        .map((e) => e.key)
        .toSet();

    expect(known, contains('ba.isolated'));
    expect(known, contains('ta.isolated'));
  });

  test('за 30 уроков открываются формы, а не только изолированные', () {
    final progress = walk(30).progress;
    final touched = progress.keys.where((id) => id.contains('.final')).toList();
    expect(touched, isNotEmpty, reason: 'цепочка форм так и не начата');
  });
}
