import 'package:get/get.dart';

import 'debug_page_controller.dart';

class DebugPageBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DebugController());
  }
}
