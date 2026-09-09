import 'package:arabic_tajweed_app/data/utils/shared_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceManager {
  final SharedPreferences _prefs;

  SharedPreferenceManager(this._prefs);

  late final isOnboardingShown = BoolSharedPref('isOnboardingShown', _prefs);
  late final authToken = StringSharedPref('authToken', _prefs);
}
