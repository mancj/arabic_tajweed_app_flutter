import 'package:get/get.dart';

import 'app_widgets_controller.dart';

class AppWidgetsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppWidgetsController());
  }
}
