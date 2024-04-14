import 'dart:io';

import 'package:gowalk_flutter_app/app/pages/onboarding/features_page/onboarding_features_page.dart';
import 'package:gowalk_flutter_app/data/shared_preference_manager.dart';
import 'package:gowalk_flutter_app/plugins/gowalk_helper/gowalk_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class SplashScreenController extends GetxController {
  final _preferenceManager = Get.find<SharedPreferenceManager>();
  final _gowalkHelper = Get.find<GowalkHelperPlugin>();

  @override
  void onReady() {
    super.onReady();

    Future.delayed(800.milliseconds, () {
      _init();
    });
  }

  Future<void> _init() async {
    if (Platform.isIOS) {
      await _gowalkHelper.initPlugin(
        appleAppID: "",
        adaptyKey: "",
        oneSignalApiKey: "",

      );
      await _gowalkHelper.prepareHelper();
      await _gowalkHelper.initializeOnboarding(forceShowOnboarding: false);
    }
    if (_preferenceManager.isOnboardingShown) {

    } else {
      Get.offNamed(OnboardingFeaturesPage.routeName);
    }
  }
}
