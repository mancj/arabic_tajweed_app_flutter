import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
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
    // TODO(onboarding): пока все идут одним путём. Когда появится онбординг,
    // новичка спрашиваем о знакомстве с письмом и разводим по трекам,
    // см. SPEC.md §8.
    _preferenceManager.isOnboardingShown.get();

    // Точка входа — главный экран курса: темы и кнопка «Продолжить».
    Get.offNamed(CoursePage.routeName);
  }
}
