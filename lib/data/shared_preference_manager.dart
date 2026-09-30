import 'package:arabic_tajweed_app/data/rest/api_config.dart';
import 'package:arabic_tajweed_app/data/utils/shared_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceManager {
  final SharedPreferences _prefs;

  SharedPreferenceManager(this._prefs);

  late final isOnboardingShown = BoolSharedPref('isOnboardingShown', _prefs);
  late final authToken = StringSharedPref('authToken', _prefs);
  late final serverUrl = StringSharedPref(
    'serverUrl',
    _prefs,
    defaultValue: ApiConfig.baseUrl,
  );
  late final colorScheme = StringSharedPref('debugColorScheme', _prefs);
  // Создаётся один раз при запуске приложения. Сбой голоса и выбор пропуска
  // действуют до завершения этого запуска, а не сохраняются на устройстве.
  bool pronunciationDisabledForRun = false;
  final pronunciationTechnicalSkipSessionsForRun = <int>{};
  int pronunciationSessionCounterForRun = 0;
}
