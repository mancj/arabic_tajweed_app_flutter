import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceManager {
  final SharedPreferences _prefs;
  static const String _isOnboardingShownKey = "isOnboardingShown";

  SharedPreferenceManager(this._prefs);

  Future<void> setIsOnboardingShown(bool isOnboardingShown) async {
    _prefs.setBool(_isOnboardingShownKey, isOnboardingShown);
  }

  bool get isOnboardingShown => _prefs.getBool(_isOnboardingShownKey) ?? false;
}
