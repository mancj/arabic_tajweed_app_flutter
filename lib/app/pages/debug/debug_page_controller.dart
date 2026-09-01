import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/pages/alphabet_letter/alphabet_letter_page.dart';
import 'package:arabic_tajweed_app/app/pages/home/home_page.dart';

class DebugController extends GetxController {
  void openHome() => Get.toNamed(HomePage.routeName);

  void openAlphabetLetter() => Get.toNamed(AlphabetLetterPage.routeName);
}
