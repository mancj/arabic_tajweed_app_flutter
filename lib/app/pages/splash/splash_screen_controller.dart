import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/pages/debug/debug_page.dart';
import 'package:arabic_tajweed_app/app/pages/home/home_page.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';

class SplashScreenController extends GetxController {
  final _preferenceManager = Get.find<SharedPreferenceManager>();

  @override
  void onReady() {
    super.onReady();

    Future.delayed(800.milliseconds, () {
      _init();
    });
  }

  Future<void> _init() async {
    // В дебажных сборках стартуем с меню отладки, в релизе — сразу на главную.
    if (kDebugMode) {
      Get.offNamed(DebugPage.routeName);
      return;
    }

    if (_preferenceManager.isOnboardingShown.get() ?? false) {
      Get.offNamed(HomePage.routeName);
    } else {
      Get.offNamed(HomePage.routeName);
    }
  }
}
