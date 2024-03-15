class OnboardingStep {
  final dynamic id;

  OnboardingStep({
    required this.id,
  });
}

class OnboardingQuestionStep extends OnboardingStep {
  final String question;
  final List<String> variants;
  int? selectedVariant;

  OnboardingQuestionStep({
    required super.id,
    required this.question,
    required this.variants,
    this.selectedVariant,
  });
}

class OnboardingFeature {
  final String title;
  final String subtitle;
  final String? videoAssetUrl;
  final String? imageAssetUrl;

  OnboardingFeature({
    required this.title,
    required this.subtitle,
    this.videoAssetUrl,
    this.imageAssetUrl,
  });
}
