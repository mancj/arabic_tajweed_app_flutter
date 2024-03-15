import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:gowalk_flutter_app/app/widgets/margin.dart';
import 'package:gowalk_flutter_app/app/widgets/transparent_gesture_detector.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';

import '../resources/onboarding_colors.dart';
import '../resources/onboarding_text_styles.dart';
import 'onboarding_features_controller.dart';

export 'onboarding_features_binding.dart';
export 'onboarding_features_controller.dart';

class OnboardingFeaturesPage extends GetView<OnboardingFeaturesController> {
  static const routeName = '/onboarding_features';
  static const double textContainerHeight = 280;

  const OnboardingFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.pageBackground,
      body: Obx(
            () => controller.isLoading
            ? const Center(
          child: CircularProgressIndicator.adaptive(),
        )
            : Stack(
          alignment: Alignment.center,
          children: [
            Expanded(
              child: PageView.builder(
                physics: const NeverScrollableScrollPhysics(),
                controller: controller.pageController,
                itemBuilder: (context, index) {
                  return _page(index);
                },
                itemCount: controller.features.length,
              ),
            ),
            _indicator(),
          ],
        ),
      ),
    );
  }

  Widget _page(int index) {
    var feature = controller.features[index];
    return Column(
      children: [
        if (feature.videoAssetUrl != null)
          Expanded(
            child: _videoPlayer(index),
          ),
        if (feature.imageAssetUrl != null)
          Expanded(
            child: Image.asset(feature.imageAssetUrl!),
          ),
        Container(
          constraints: const BoxConstraints(maxHeight: textContainerHeight),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          color: OnboardingColors.primary,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                feature.title,
                style: OnboardingTextStyles.featureTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              const Margin.vertical(12),
              Text(
                feature.subtitle,
                style: OnboardingTextStyles.featureSubtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              _nextPageButton(index),
            ],
          ),
        ),
      ],
    );
  }

  Widget _indicator() {
    return Positioned(
      bottom: textContainerHeight,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SmoothPageIndicator(
          controller: controller.pageController!,
          count: controller.features.length,
          effect: const ExpandingDotsEffect(
            activeDotColor: OnboardingColors.primary,
            dotColor: OnboardingColors.white,
            expansionFactor: 2,
            dotHeight: 8,
          ),
          onDotClicked: (index) {},
        ),
      ),
    );
  }

  Widget _videoPlayer(int index) {
    final playerController = controller.videoPlayerController;
    return playerController?.value.isInitialized ?? false
        ? LayoutBuilder(
      builder: (context, constraints) {
        var d =
            constraints.maxHeight / playerController!.value.size.height;
        var w = playerController.value.size.width * d;
        return Container(
          color: OnboardingColors.primary,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: constraints.maxHeight,
            child: OverflowBox(
              maxWidth: w,
              maxHeight: playerController.value.size.height * d,
              // maxHeight: a,
              child: VideoPlayer(
                playerController,
              )
                  .animate(
                key: ValueKey(index),
                delay: 200.milliseconds,
              )
                  .fadeIn(),
            ),
          ),
        );
      },
    )
        : const ColoredBox(color: OnboardingColors.primary);
  }

  Widget _nextPageButton(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TransparentGestureDetector(
        onTap: () => controller.nextPage(),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                alignment: Alignment.center,
                width: 52,
                height: 52,
                decoration: const ShapeDecoration(
                  shape: CircleBorder(),
                  color: OnboardingColors.white,
                ),
                child: const Icon(Icons.chevron_right_outlined),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: controller.getProgressForPage(index),
                  valueColor: const AlwaysStoppedAnimation(
                    OnboardingColors.white,
                  ),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
