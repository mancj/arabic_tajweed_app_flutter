import 'package:flutter/cupertino.dart';

import 'onboarding_colors.dart';

class OnboardingTextStyles {

  static const secondarySmallBold = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: OnboardingColors.secondaryText,
  );

  static const onboardingQuestionTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: OnboardingColors.textColor,
  );

  static const buttonTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const normalBold = TextStyle(
    fontSize: 17,
    color: OnboardingColors.black,
    fontWeight: FontWeight.bold,
  );

  static const normalSemibold = TextStyle(
    fontSize: 17,
    color: OnboardingColors.textColor,
    fontWeight: FontWeight.w600,
  );

  static const secondaryText = TextStyle(
    fontSize: 17,
    height: 1.2,
    color: OnboardingColors.secondaryText,
  );

  static const featureTitle = TextStyle(
    fontSize: 28,
    color: OnboardingColors.white,
    fontWeight: FontWeight.w800,
  );

  static const featureSubtitle = TextStyle(
    fontSize: 18,
    color: OnboardingColors.white,
    fontWeight: FontWeight.w600,
  );

}
