
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
        id: "usage_purpose",
        question: "What are you hoping to detect with our app? 🕵️‍♂️",
        variants: [
          "Gold 💰",
          "Lost metal items 🔍",
          "Finding buried treasure ⛏️",
          "Locating metal pipes or wires 🔧",
        ],
      ),
      OnboardingQuestionStep(
        id: "app_interests",
        question: "Which feature interests you the most? 🤔",
        variants: [
          "Adjustable sensitivity settings ⚙️",
          "Visual and audio feedback when metal is detected 🔊👀",
          "GPS integration for marking found items 🗺️",
        ],
      ),
      OnboardingQuestionStep(
        id: "location_type",
        question:
            "Do you plan to use the app primarily indoors or outdoors? 🏠🌳",
        variants: [
          "Indoors 🏢",
          "Outdoors 🌄",
          "Both 🏠🌳",
        ],
      ),
      OnboardingQuestionStep(
        id: "join_community",
        question: "Are you interested in joining our community? 🤝",
        variants: [
          "Yes, I'd love to connect with other users! 👥",
          "Maybe later, I prefer exploring the app first. 🤷‍♂️",
          "No, I prefer using the app independently. 🚶‍♂️",
        ],
      ),
      OnboardingQuestionStep(
        id: "use_frequency",
        question: "How frequently do you plan to use the app? ⌚",
        variants: [
          "Occasionally, for recreational purposes 🎣",
          "Regularly, for professional or hobbyist projects 🛠️",
          "Rarely, just for specific occasions 📅",
        ],
      ),
      OnboardingQuestionStep(
        id: "notifications",
        question: "Would you like to receive notification for updates? 🔔",
        variants: [
          "Yes, I want to stay informed. 📲",
          "No, I prefer to check for updates manually. 📡",
          "Maybe later, I'm undecided. 🤔",
        ],
      ),
      OnboardingQuestionStep(
        id: "usage_experience",
        question: "How familiar are you with metal detection? 🤖",
        variants: [
          "Beginner 🚸",
          "Intermediate 🎓",
          "Advanced 🏆",
        ],
      ),
      OnboardingQuestionStep(
        id: "app_customization",
        question: "Would you like to customize your app? 🎨",
        variants: [
          "Yes, I'd like to customize it. 🖌️",
          "No, I'm fine with default settings. 🛑",
          "Maybe later, I want to explore the app first. 🤷",
        ],
      ),
    ];
    _features = [
      OnboardingFeature(
          title: "Strong Sensors",
          videoAssetUrl: "assets/video/onboarding_feature_1.mp4",
          subtitle: "The app uses special algorithms and has strong sensors "
              "able to detect metal anywhere!"),
      OnboardingFeature(
          title: "Fun Experience",
          videoAssetUrl: "assets/video/onboarding_feature_2.mp4",
          subtitle:
              "Vibrates to inform you once you find your treasures!"),
      OnboardingFeature(
          title: "Find Metals Easily",
          videoAssetUrl: "assets/video/onboarding_feature_3.mp4",
          subtitle:
              "The app can be used to find metal, precious metals, and lost devices"),
    ];
    _isInitialized = true;
  }
}
