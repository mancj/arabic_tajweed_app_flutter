import 'package:gowalk_flutter_app/data/shared_preference_manager.dart';
import 'package:gowalk_flutter_app/plugins/gowalk_helper/gowalk_helper.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class   AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(GowalkHelperPlugin());
  }

  Future<void> asyncDependencies() async {
    await Get.putAsync(() async {
      var prefs = await SharedPreferences.getInstance();
      return SharedPreferenceManager(prefs);
    });
  }
}
