import 'dart:io';

import 'package:gowalk_flutter_app/data/shared_preference_manager.dart';
import 'package:gowalk_flutter_app/plugins/gowalk_helper/gowalk_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class OnboardingAnalyzingController extends GetxController {
  final _gowalkHelper = Get.find<GowalkHelperPlugin>();
  final _preferenceManager = Get.find<SharedPreferenceManager>();
  final _analysisStepIndex = RxInt(0);

  int get analysisStepIndex => _analysisStepIndex.value;

  void increaseStepIndex() {
    _analysisStepIndex.value++;
  }

  bool isStepPassed(int index) {
    return index < analysisStepIndex;
  }

  bool isAnimatingStep(int index) {
    return index == analysisStepIndex;
  }

  Future<void> proceedNextPage() async {
    if (Platform.isIOS) {
      await _gowalkHelper.setOnboardingPassed(true);
      await _preferenceManager.setIsOnboardingShown(true);
      if (!kDebugMode) await _gowalkHelper.showPaywall("onboarding");
    }
    Future.delayed(300.milliseconds, () {
      throw Exception("You should handle navigation at this point");
    });
  }
}
