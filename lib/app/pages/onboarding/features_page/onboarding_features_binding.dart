import 'package:get/get.dart';

import 'onboarding_features_controller.dart';

class OnboardingFeaturesBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(OnboardingFeaturesController());
  }

}
