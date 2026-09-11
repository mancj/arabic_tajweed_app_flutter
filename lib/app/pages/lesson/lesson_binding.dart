import 'package:get/get.dart';

import 'lesson_controller.dart';
import '../../../domain/planner.dart';

class LessonBinding extends Bindings {
  /// Ключ аргумента маршрута: id темы, урок по которой открывают.
  /// Без него урок собирается планировщиком как обычно.
  static const topicArg = 'topicId';
  static const planArg = 'plan';
  static const continuePlanningArg = 'continuePlanning';

  @override
  void dependencies() {
    final args = Get.arguments;
    final topicId = args is Map ? args[topicArg] as String? : null;
    // Именно put, а не lazyPut: при повторном заходе на урок GetX вернул бы
    // прежний экземпляр, уже досмотренный до экрана «Урок пройден».
    Get.put(
      LessonController(
        topicId: topicId,
        plan: args is Map ? args[planArg] as LessonPlan? : null,
        continuePlanning: args is Map
            ? args[continuePlanningArg] as bool? ?? false
            : true,
      ),
    );
  }
}
