import 'onboarding_question.dart';

class OnboardingStepsProvider {
  static bool _isInitialized = false;
  static List<OnboardingStep> _steps = [];
  static List<OnboardingFeature> _features = [];

  static List<OnboardingStep> get steps {
    _init();
    return _steps;
  }

  static List<OnboardingFeature> get features {
    _init();
    return _features;
  }

  static void _init() {
    if (_isInitialized) return;
    _steps = [
      OnboardingQuestionStep(
        id: "tv_brand",
        question: "Which TV brand do you own? 📺",
        variants: ["Samsung", "LG", "Sony", "Panasonic", "Other"],
      ),
      OnboardingQuestionStep(
        id: "usage_frequency",
        question: "How often do you plan to use this remote app? ⌚",
        variants: ["Daily", "A few times a week", "Occasionally", "Rarely"],
      ),
      OnboardingQuestionStep(
        id: "feature_importance",
        question: "Which feature is most important to you? 🎚️",
        variants: [
          "Universal remote capabilities",
          "Volume control and mute",
          "Power on/off",
          "Voice commands"
        ],
      ),
      OnboardingQuestionStep(
        id: "connect_devices",
        question: "Do you want to control other devices besides your TV? 🔌",
        variants: [
          "Yes, all my smart home devices",
          "Just audio devices like speakers",
          "Only my TV",
          "Not sure yet"
        ],
      ),
      OnboardingQuestionStep(
        id: "customization_preference",
        question:
            "Do you prefer a personalized or standard layout for your remote? 🎨",
        variants: [
          "Personalized layout",
          "Standard layout",
          "Decide after trying the standard"
        ],
      ),
      OnboardingQuestionStep(
        id: "notification_preference",
        question:
            "Would you like to receive notifications about app updates or offers? 🔔",
        variants: [
          "Yes, keep me updated",
          "No, I'll check manually",
          "Only critical updates"
        ],
      ),
      OnboardingQuestionStep(
        id: "help_tutorials",
        question: "Do you want to watch tutorials on how to use the app? 🎥",
        variants: [
          "Yes, show me the tutorials",
          "No, I can figure it out myself",
          "Only for advanced features"
        ],
      ),
    ];
    _features = [
      OnboardingFeature(
          title: "Master All Android TV Devices",
          imageAssetUrl: "assets/img/png/onboarding_feature_1.jpg",
          subtitle: "Gain complete control over every Android TV in your home with a single app."),
      OnboardingFeature(
          title: "Instant Connection Setup",
          imageAssetUrl: "assets/img/png/onboarding_feature_2.jpg",
          subtitle: "Connect to your devices quickly with our straightforward pairing process"),
      OnboardingFeature(
          title: "Optimized for Android Compatibility",
          imageAssetUrl: "assets/img/png/onboarding_feature_3.jpg",
          subtitle:
              "Designed to work perfectly with all your Android-based devices"),
    ];
    _isInitialized = true;
  }
}
