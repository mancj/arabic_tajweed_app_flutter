import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:arabic_tajweed_app/data/rest/api_config.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';
import 'package:arabic_tajweed_app/app/pages/atom_progress/atom_progress_page.dart';
import 'package:arabic_tajweed_app/app/pages/app_widgets/app_widgets_page.dart';
import 'package:arabic_tajweed_app/app/pages/tracing/tracing_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';
import 'package:arabic_tajweed_app/app/pages/pronunciation/pronunciation_page.dart';

import 'form_sequence_debug_page.dart';

class DebugController extends GetxController {
  final serverUrl = ''.obs;

  SharedPreferenceManager get _preferences =>
      Get.find<SharedPreferenceManager>();

  @override
  void onInit() {
    super.onInit();
    serverUrl.value = _preferences.serverUrl.get() ?? ApiConfig.baseUrl;
  }

  /// Сохраняет адрес и сразу переключает уже созданный API-клиент.
  Future<bool> saveServerUrl(String value) async {
    try {
      final normalized = ApiConfig.normalizeBaseUrl(value);
      await _preferences.serverUrl.set(normalized);
      Get.find<Dio>().options.baseUrl = normalized;
      serverUrl.value = normalized;
      Get.snackbar('Адрес сервера изменён', normalized);
      return true;
    } on FormatException catch (error) {
      Get.snackbar('Некорректный адрес', error.message.toString());
      return false;
    }
  }

  /// Сбросить прогресс: лог стирается, курс начинается с первого урока.
  /// Нужно, чтобы проверять правки в контенте — иначе пройденные уроки
  /// заново не показываются.
  Future<void> resetProgress() async {
    await Get.find<ProgressDatabase>().clear();
    Get.snackbar(
      'Прогресс сброшен',
      'Курс начнётся с первого урока',
      duration: .5.seconds,
    );
  }

  void openCourse() => Get.toNamed(CoursePage.routeName);

  void openAtomProgress() => Get.toNamed(AtomProgressPage.routeName);

  void openLesson() => Get.toNamed(LessonPage.routeName);

  void openTracing() => Get.toNamed(TracingPage.routeName);

  void openPronunciation() => Get.toNamed(PronunciationPage.routeName);

  void openAlphabetLetter() => Get.toNamed(AlphabetLetterPage.routeName);

  void openAppWidgetsPage() => Get.toNamed(AppWidgetsPage.routeName);

  void openFormSequence() => Get.toNamed(FormSequenceDebugPage.routeName);
}
