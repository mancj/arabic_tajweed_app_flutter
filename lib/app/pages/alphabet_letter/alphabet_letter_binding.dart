import 'package:get/get.dart';

import 'alphabet_letter_controller.dart';

class AlphabetLetterBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AlphabetLetterController());
  }
}
