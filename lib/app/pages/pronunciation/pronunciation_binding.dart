import 'package:get/get.dart';

import 'pronunciation_controller.dart';

class PronunciationBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(PronunciationController());
  }
}
