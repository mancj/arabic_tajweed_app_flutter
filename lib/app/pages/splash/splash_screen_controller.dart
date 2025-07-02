import 'package:get/get.dart';
import 'package:my_app_template/app/pages/home/home_page.dart';
import 'package:my_app_template/data/shared_preference_manager.dart';

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
    if (_preferenceManager.isOnboardingShown.get() ?? false) {
      Get.offNamed(HomePage.routeName);
    } else {
      Get.offNamed(HomePage.routeName);
    }
  }
}
