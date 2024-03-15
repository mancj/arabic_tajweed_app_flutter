import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/onboarding_question.dart';
import '../resources/onboarding_colors.dart';
import 'onboarding_controller.dart';
import 'widgets/question_page_widget.dart';

export 'onboarding_binding.dart';
export 'onboarding_controller.dart';

class OnboardingPage extends GetView<OnboardingController> {
  static const routeName = '/onboarding';

  const OnboardingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.pageBackground,
      body: SafeArea(
        child: Obx(
              () => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
                child: LinearProgressIndicator(
                  value: controller.pageProgress,
                  minHeight: 8,
                  valueColor:
                  const AlwaysStoppedAnimation(OnboardingColors.primary),
                  backgroundColor: OnboardingColors.onboardingProgressBg,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              if (true && kDebugMode)
                TextButton(
                    onPressed: () => controller.skip(), child: Text("Skip")),
              Expanded(
                child: PageView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: controller.pageController,
                  itemBuilder: (context, index) {
                    final step = controller.steps[index];
                    if (step is OnboardingQuestionStep) {
                      return QuestionPageWidget(
                        step,
                        onContinueTap: controller.nextPage,
                        pageProgress: 0,
                        onVariantTap: (int index) =>
                            controller.selectAnswer(step, index),
                      );
                    }
                    return null;
                  },
                  itemCount: controller.steps.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
