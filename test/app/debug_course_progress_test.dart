import 'dart:async';
import 'dart:io';

import 'package:arabic_tajweed_app/app/pages/course/course_controller.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_controller.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Защищает «Мой путь» от чередования незавершённых букв и готовых форм.
/// Отладочный верный ответ должен сохранять настоящий режим каждого задания.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final curriculum = CurriculumLoader.parse(
    File('assets/curriculum/stage1.json').readAsStringSync(),
  );
  late ProgressDatabase database;

  setUp(() {
    database = ProgressDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('правильный прогон до ع غ закрывает каждый предыдущий блок', () async {
    const targetTopicId = 'm.ayn';

    for (var session = 0; session < 40; session++) {
      final course = CourseController(
        database: database,
        curriculum: curriculum,
      );
      await course.refreshBoard();
      final target = course.statuses.firstWhere(
        (status) => status.topic.id == targetTopicId,
      );
      if (target.isDone) break;

      final controller = LessonController(
        database: database,
        curriculum: curriculum,
        continuePlanning: true,
        shapeLoader: (_) async =>
            throw UnsupportedError('Холст здесь не проверяется'),
      );
      final ready = Completer<void>();
      final subscription = controller.stage.listen((stage) {
        if (stage != LessonStage.loading && !ready.isCompleted) {
          ready.complete();
        }
      });
      controller.onInit();
      await ready.future.timeout(const Duration(seconds: 5));
      await subscription.cancel();

      var steps = 0;
      while (controller.stage.value != LessonStage.finished) {
        expect(steps++, lessThan(100));
        if (controller.stage.value == LessonStage.intro) {
          await controller.nextIntro();
          continue;
        }
        while (controller.card.value != null) {
          await controller.dismissCard();
        }
        await controller.answerCorrectly(advance: true);
      }
      controller.onClose();
    }

    final course = CourseController(database: database, curriculum: curriculum);
    await course.refreshBoard();
    final throughTarget = course.statuses.takeWhile(
      (status) => status.topic.id != 'm.ayn.forms',
    );
    expect(throughTarget, isNotEmpty);
    expect(
      throughTarget
          .where((status) => !status.isDone)
          .map((status) => status.topic.id),
      isEmpty,
    );
  });
}
