import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/course/course_controller.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/domain/lesson_pacing.dart';
import 'package:arabic_tajweed_app/domain/planner.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ExpectedLesson = ({
  String? topicId,
  LessonPurpose purpose,
  int? checkpoint,
});

/// Сквозная фиксация двух согласованных последовательностей: один урок в
/// день и несколько уроков в один день. Все ответы даются правильно.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  late ProgressDatabase database;
  late DateTime now;
  late AppClock clock;

  setUp(() {
    database = ProgressDatabase(NativeDatabase.memory());
    now = DateTime(2026, 1, 1, 12);
    clock = AppClock(systemNow: () => now);
  });

  tearDown(() => database.close());

  Future<LessonPlan> completeNextLesson() async {
    final course = CourseController(
      database: database,
      curriculum: curriculum,
      clock: clock,
    );
    await course.refreshBoard();
    expect(course.loadError.value, isNull);
    final plan = course.nextPlan.value!;

    final lesson = LessonController(
      database: database,
      curriculum: curriculum,
      plan: plan,
      continuePlanning: true,
      clock: clock,
      shapeLoader: (_) async =>
          throw UnsupportedError('Холст в проверке порядка не нужен'),
    );
    final ready = Completer<void>();
    final subscription = lesson.stage.listen((stage) {
      if (stage != LessonStage.loading && !ready.isCompleted) ready.complete();
    });
    lesson.onInit();
    await ready.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    expect(lesson.loadError.value, isNull);

    var steps = 0;
    while (lesson.stage.value != LessonStage.finished) {
      expect(
        ++steps,
        lessThan(100),
        reason: 'урок не завершился: ${plan.reason}',
      );
      if (lesson.stage.value == LessonStage.intro) {
        await lesson.nextIntro();
        continue;
      }
      while (lesson.card.value != null) {
        await lesson.dismissCard();
      }
      await lesson.answerCorrectly(advance: true);
    }
    lesson.onClose();
    return plan;
  }

  void expectLesson(LessonPlan actual, ExpectedLesson expected, int number) {
    expect(actual.topicId, expected.topicId, reason: 'занятие $number: тема');
    expect(actual.purpose, expected.purpose, reason: 'занятие $number: тип');
    expect(
      actual.checkpointLetters,
      expected.checkpoint,
      reason: 'занятие $number: рубеж',
    );
  }

  test('при трёх занятиях в день новое идёт после двух повторов', () async {
    const newTopics = [
      'm.first',
      'm.forms',
      'm.jim',
      'm.jim.forms',
      'm.nojoin',
      'm.nojoin.forms',
      'm.sin',
      'm.sin.forms',
      'm.sod',
      'm.sod.forms',
      'm.to',
      'm.to.forms',
      'm.ayn',
      'm.ayn.forms',
      'm.fa',
      'm.fa.forms',
      'm.kaf',
      'm.kaf.forms',
      'm.mim',
      'm.mim.forms',
      'm.ha',
      'm.ha.forms',
      'm.hamza',
    ];
    const checkpointAfter = {
      'm.jim.forms': 7,
      'm.sod.forms': 15,
      'm.fa.forms': 21,
      'm.hamza': 28,
    };

    var lessonNumber = 0;
    for (final (day, topicId) in newTopics.indexed) {
      now = DateTime(2026, 1, day + 1, 12);
      expectLesson(await completeNextLesson(), (
        topicId: topicId,
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ), ++lessonNumber);

      final checkpoint = checkpointAfter[topicId];
      expectLesson(await completeNextLesson(), (
        topicId: null,
        purpose: checkpoint == null
            ? LessonPurpose.mixedReview
            : LessonPurpose.alphabetCheckpoint,
        checkpoint: checkpoint,
      ), ++lessonNumber);

      expectLesson(await completeNextLesson(), (
        topicId: null,
        purpose: topicId == newTopics.last
            ? LessonPurpose.standard
            : LessonPurpose.mixedReview,
        checkpoint: null,
      ), ++lessonNumber);
    }
  });

  test('при одном занятии в день соблюдается таблица из 27 дней', () async {
    const expected = <ExpectedLesson>[
      (topicId: 'm.first', purpose: LessonPurpose.standard, checkpoint: null),
      (topicId: 'm.forms', purpose: LessonPurpose.standard, checkpoint: null),
      (topicId: 'm.jim', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.jim.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: null, purpose: LessonPurpose.alphabetCheckpoint, checkpoint: 7),
      (topicId: 'm.nojoin', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.nojoin.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.sin', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.sin.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.sod', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.sod.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (
        topicId: null,
        purpose: LessonPurpose.alphabetCheckpoint,
        checkpoint: 15,
      ),
      (topicId: 'm.to', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.to.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.ayn', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.ayn.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.fa', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.fa.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (
        topicId: null,
        purpose: LessonPurpose.alphabetCheckpoint,
        checkpoint: 21,
      ),
      (topicId: 'm.kaf', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.kaf.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.mim', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.mim.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.ha', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: 'm.ha.forms',
        purpose: LessonPurpose.standard,
        checkpoint: null,
      ),
      (topicId: 'm.hamza', purpose: LessonPurpose.standard, checkpoint: null),
      (
        topicId: null,
        purpose: LessonPurpose.alphabetCheckpoint,
        checkpoint: 28,
      ),
    ];

    for (final (index, item) in expected.indexed) {
      now = DateTime(2026, 1, index + 1, 12);
      expectLesson(await completeNextLesson(), item, index + 1);
    }
  });
}
