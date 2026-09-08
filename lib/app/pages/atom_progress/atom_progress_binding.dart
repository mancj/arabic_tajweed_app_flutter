import 'package:get/get.dart';

import 'atom_progress_controller.dart';

class AtomProgressBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(AtomProgressController.new);
  }
}
