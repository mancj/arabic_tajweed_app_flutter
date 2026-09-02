import 'package:get/get.dart';

import 'lesson_controller.dart';

class LessonBinding extends Bindings {
  /// Ключ аргумента маршрута: id темы, урок по которой открывают.
  /// Без него урок собирается планировщиком как обычно.
  static const topicArg = 'topicId';

  @override
  void dependencies() {
    final args = Get.arguments;
    final topicId = args is Map ? args[topicArg] as String? : null;
    // Именно put, а не lazyPut: при повторном заходе на урок GetX вернул бы
    // прежний экземпляр, уже досмотренный до экрана «Урок пройден».
    Get.put(LessonController(topicId: topicId));
  }
}
