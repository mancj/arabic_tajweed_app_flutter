import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/course/course_controller.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Проверяет сохранённое правило именно на доске «Мой путь»: освоенная
/// письмом буква не должна ждать несуществующего голосового ответа.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('отключённое произношение снимает его критерий с доски тем', () async {
    SharedPreferences.setMockInitialValues({'pronunciationDisabled': true});
    final preference = PronunciationPreference(
      SharedPreferenceManager(await SharedPreferences.getInstance()),
    );
    final curriculum = CurriculumLoader.parse(
      File('assets/curriculum/stage1.json').readAsStringSync(),
    );
    final database = ProgressDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final at = DateTime(2026, 9, 11);
    await database.appendAll([
      for (final mode in const [
        ExerciseMode.trace,
        ExerciseMode.traceFromMemory,
        ExerciseMode.trace,
      ])
        ProgressEvent(
          atomId: 'ba.isolated',
          sessionId: 1,
          at: at,
          mode: mode,
          correct: true,
          attempt: 1,
          fastEnough: true,
        ),
    ]);

    final course = CourseController(
      database: database,
      curriculum: curriculum,
      pronunciationPreference: preference,
    );
    await course.refreshBoard();

    expect(course.statuses.first.done, 1);
    expect(
      course.context.progress['ba.isolated']!.successfulModes,
      isNot(contains(ExerciseMode.sayName)),
    );
  });
}
