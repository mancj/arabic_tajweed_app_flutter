import 'package:gowalk_flutter_app/app/pages/onboarding/resources/onboarding_images.dart';
import 'package:gowalk_flutter_app/app/widgets/margin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

import '../resources/onboarding_colors.dart';
import '../resources/onboarding_text_styles.dart';
import 'onboarding_analyzing_page.dart';

export 'onboarding_analyzing_binding.dart';
export 'onboarding_analyzing_controller.dart';

class OnboardingAnalyzingPage extends GetView<OnboardingAnalyzingController> {
  static const routeName = "/onboarding_analyzing";

  const OnboardingAnalyzingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox.expand(
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Margin.vertical(16),
                  Image.asset(
                    OnboardingImages.analysis_avatar,
                    width: 180,
                    // height: 180,
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                        begin: .95,
                        end: 1,
                        duration: 2.seconds,
                      ),
                  const Margin.vertical(16),
                  const Text(
                    "Customizing your experience...",
                    style: TextStyle(
                      color: OnboardingColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  _analysisItemWidget(
                    index: 0,
                    title: "Analysing your answers",
                    analysisDuration: 8.seconds,
                    onComplete: () => controller.increaseStepIndex(),
                  ),
                  _analysisItemWidget(
                    index: 1,
                    title: "Preparing Metal Detectors",
                    analysisDuration: 6.seconds,
                    onComplete: () => controller.increaseStepIndex(),
                  ),
                  _analysisItemWidget(
                    index: 2,
                    title: "Forming Strong Sensors",
                    analysisDuration: 9.seconds,
                    onComplete: () => controller.proceedNextPage(),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Column _analysisItemWidget({
    required String title,
    required int index,
    required Duration analysisDuration,
    required Function() onComplete,
  }) {
    var isPassed = controller.isStepPassed(index);
    var isAnimating = controller.isAnimatingStep(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Margin.horizontal(8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: isPassed
                  ? const Icon(
                      Icons.check_circle,
                      color: OnboardingColors.primary,
                      size: 24,
                    )
                  : isAnimating
                      ? const Icon(
                          Icons.circle,
                          size: 14,
                          color: OnboardingColors.secondaryText,
                        )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                            delay: 200.ms,
                            begin: .8,
                            end: 1,
                            duration: 150.ms,
                          )
                      : const Icon(
                          Icons.circle,
                          size: 14,
                          color: OnboardingColors.secondaryText,
                        ),
            ),
            const Margin.horizontal(16),
            Flexible(
              child: Text(
                title,
                style: isPassed || isAnimating
                    ? OnboardingTextStyles.normalSemibold
                    : OnboardingTextStyles.secondaryText,
              ),
            ),
          ],
        ),
        const Margin.vertical(8),
        if (isAnimating)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Animate(
              onComplete: (c) => onComplete(),
            ).custom(
              begin: 0,
              end: 1,
              duration: analysisDuration,
              curve: Curves.easeInOut,
              builder: (a, b, c) {
                return LinearProgressIndicator(
                  value: b,
                  minHeight: 8,
                  valueColor: const AlwaysStoppedAnimation(
                    OnboardingColors.primary,
                  ),
                  backgroundColor: OnboardingColors.onboardingProgressBg,
                  color: OnboardingColors.onboardingProgressBg,
                  borderRadius: BorderRadius.circular(18),
                );
              },
            ),
          ),
        if (isPassed)
          const Padding(
            padding: EdgeInsets.only(left: 38),
            child: Text(
              "Done",
              style: OnboardingTextStyles.secondarySmallBold,
            ),
          ),
        Divider(
          height: 24,
          color: OnboardingColors.secondaryText.withAlpha(30),
        ),
      ],
    );
  }
}
