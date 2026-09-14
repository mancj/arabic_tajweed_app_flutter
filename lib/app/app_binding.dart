import 'package:arabic_tajweed_app/app/shared_state/auth_state.dart';
import 'package:arabic_tajweed_app/app/shared_state/app_clock.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/rest/api_client.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_rest_client.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Сеть. Порядок важен: клиенты берут Dio через Get.find,
    // поэтому сначала AuthState (токен для заголовков), потом Dio, потом клиенты.
    final authState = Get.put(AuthState(Get.find()), permanent: true);
    Get.put(createApiClient(authState), permanent: true);
    _setupRestClients();
  }

  /// Клиенты сервера, по одному на область API.
  void _setupRestClients() {
    Get.put(PronunciationRestClient(), permanent: true);
  }

  Future<void> asyncDependencies() async {
    final preferences = await SharedPreferences.getInstance();
    Get.put(SharedPreferenceManager(preferences));
    Get.put(AppClock(preferences: preferences), permanent: true);

    // Одна база на всё приложение: лог событий append-only.
    Get.put(ProgressDatabase(), permanent: true);
  }
}
