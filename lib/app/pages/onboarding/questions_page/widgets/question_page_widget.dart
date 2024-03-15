import 'package:gowalk_flutter_app/app/widgets/margin.dart';
import 'package:gowalk_flutter_app/app/widgets/primary_button.dart';
import 'package:gowalk_flutter_app/app/widgets/transparent_gesture_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/onboarding_question.dart';
import '../../resources/onboarding_colors.dart';
import '../../resources/onboarding_text_styles.dart';

class QuestionPageWidget extends StatelessWidget {
  final OnboardingQuestionStep step;
  final Function() onContinueTap;
  final Function(int index) onVariantTap;
  final double pageProgress;

  const QuestionPageWidget(
    this.step, {
    Key? key,
    required this.onContinueTap,
    required this.pageProgress,
    required this.onVariantTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            step.question,
            style: OnboardingTextStyles.onboardingQuestionTitle,
            textAlign: TextAlign.center,
          ),
          const Margin.vertical(24),
          Expanded(
              child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < step.variants.length; ++i)
                  _answerWidget(step.variants[i], i == step.selectedVariant, i),
              ],
            ),
          )),
          step.selectedVariant != null
              ? PrimaryButton(
                  title: "Continue",
                  onTap: onContinueTap,
                ).animate().fadeIn(duration: 200.ms)
              : const SizedBox(height: 55),
        ],
      ),
    );
  }

  Widget _answerWidget(String title, bool isSelected, int index) {
    return TransparentGestureDetector(
      onTap: () => onVariantTap(index),
      child: Container(
        // height: 70,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OnboardingColors.cardBg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: OnboardingColors.white,
                    border: Border.all(
                      color: isSelected
                          ? OnboardingColors.radioButtonOutlineActive
                          : OnboardingColors.radioButtonOutlineInactive,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: OnboardingColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .scaleXY(duration: 200.ms, curve: Curves.easeInOut),
              ],
            ),
            const Margin.horizontal(16),
            Expanded(
              child: Text(
                title,
                style: OnboardingTextStyles.buttonTitle.copyWith(
                  color: OnboardingColors.black,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
