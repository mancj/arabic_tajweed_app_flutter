import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../data/onboarding_question.dart';
import '../data/onboarding_steps_provider.dart';
import '../questions_page/onboarding_page.dart';

class OnboardingFeaturesController extends GetxController {
  List<OnboardingFeature> get features => OnboardingStepsProvider.features;
  PageController? pageController;
  final _isLoading = RxBool(true);
  VideoPlayerController? videoPlayerController;

  bool get isLoading => _isLoading.value;

  int currentPage = 0;

  @override
  void onReady() {
    super.onReady();
    _init();
  }

  Future<void> _init() async {
    pageController = PageController();
    await _initVideoController(0);
    _isLoading.value = false;
  }

  Future<void> _initVideoController(int index) async {
    await videoPlayerController?.dispose();
    videoPlayerController = null;
    var videoUrl = features[index].videoAssetUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      videoPlayerController = VideoPlayerController.asset(videoUrl);
      await videoPlayerController?.initialize();
      videoPlayerController?.setLooping(true);
      videoPlayerController?.play();
      refresh();
      _isLoading.refresh();
    }
  }

  @override
  void onClose() {
    super.onClose();
    videoPlayerController?.dispose();
    videoPlayerController = null;
  }

  double getProgressForPage(int page) {
    return (page + 1) / features.length;
  }

  Future<void> nextPage() async {
    var nextPage = pageController!.page!.toInt() + 1;
    currentPage = nextPage;
    if (nextPage == features.length) {
      Get.offNamed(OnboardingPage.routeName);
      return;
    }
    var duration = 400;
    pageController?.nextPage(
      duration: duration.milliseconds,
      curve: Curves.easeInOut,
    );
    Future.delayed(100.milliseconds, () {
      _initVideoController(nextPage);
    });
  }
}
