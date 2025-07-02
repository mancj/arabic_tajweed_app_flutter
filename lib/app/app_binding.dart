import 'package:my_app_template/data/shared_preference_manager.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class   AppBinding extends Bindings {
  @override
  void dependencies() {
  }

  Future<void> asyncDependencies() async {
    await Get.putAsync(() async {
      var prefs = await SharedPreferences.getInstance();
      return SharedPreferenceManager(prefs);
    });
  }
}
