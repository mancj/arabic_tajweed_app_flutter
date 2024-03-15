import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../analyzing_page/onboarding_analyzing_page.dart';
import '../data/onboarding_question.dart';
import '../data/onboarding_steps_provider.dart';

class OnboardingController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final RxList<OnboardingStep> steps = RxList();
  late final PageController pageController = PageController();
  final _pageProgress = RxDouble(.05);

  late AnimationController _progressAnimController;
  late Animation<double> _progressAnim;

  double get pageProgress => _pageProgress.value;

  @override
  void onReady() {
    super.onReady();
    steps.addAll(OnboardingStepsProvider.steps);

    _progressAnimController = AnimationController(
      vsync: this,
      duration: 500.milliseconds,
    );
  }

  @override
  void onClose() {
    super.onClose();
    _progressAnimController.dispose();
  }

  void nextPage() {
    var page = pageController.page!.toInt() + 1;
    if (page >= steps.length) {
      proceedNextPage();
      return;
    }

    pageController.nextPage(
      duration: 300.milliseconds,
      curve: Curves.easeInOut,
    );
    var oldProgress = (pageController.page!.toInt() + 1) / steps.length;
    var newProgress = (pageController.page!.toInt() + 2) / steps.length;

    final curvedAnim = CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeIn,
    );
    _progressAnim =
    Tween<double>(begin: oldProgress, end: newProgress).animate(curvedAnim)
      ..addListener(() {
        _pageProgress.value = _progressAnim.value;
      });
    _progressAnimController.reset();
    _progressAnimController.forward();
  }

  void proceedNextPage() {
    Get.offNamed(OnboardingAnalyzingPage.routeName);
  }

  selectAnswer(OnboardingQuestionStep step, int index) {
    step.selectedVariant = index;
    steps.refresh();
  }

  skip() {
    proceedNextPage();
  }
}
