import 'package:get/get.dart';
import 'package:arabic_tajweed_app/data/progress_database.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';
import 'package:arabic_tajweed_app/app/pages/atom_progress/atom_progress_page.dart';
import 'package:arabic_tajweed_app/app/pages/app_widgets/app_widgets_page.dart';
import 'package:arabic_tajweed_app/app/pages/home/home_page.dart';
import 'package:arabic_tajweed_app/app/pages/course/course_page.dart';
import 'package:arabic_tajweed_app/app/pages/lesson/lesson_page.dart';

class DebugController extends GetxController {
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

  void openHome() => Get.toNamed(HomePage.routeName);

  void openAlphabetLetter() => Get.toNamed(AlphabetLetterPage.routeName);

  void openAppWidgetsPage() => Get.toNamed(AppWidgetsPage.routeName);
}
