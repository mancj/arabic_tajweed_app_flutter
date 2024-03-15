import 'package:get/get.dart';

import 'onboarding_analyzing_page.dart';

class OnboardingAnalyzingBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(OnboardingAnalyzingController());
  }
}
