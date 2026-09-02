import 'package:get/get.dart';

import 'course_controller.dart';

class CourseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(CourseController.new);
  }
}
