import 'package:get/get.dart';

import 'tracing_page_controller.dart';

class TracingPageBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TracingController());
  }
}
