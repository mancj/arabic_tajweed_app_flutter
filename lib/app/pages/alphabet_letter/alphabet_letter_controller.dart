import 'package:get/get.dart';

/// Одна из позиционных форм буквы в карточках под основной.
class LetterForm {
  final int index;
  final String glyph;
  final String title;

  const LetterForm({
    required this.index,
    required this.glyph,
    required this.title,
  });
}

class AlphabetLetterController extends GetxController {
  final label = 'Новая буква';
  final glyph = 'ج';
  final name = 'Джим';
  final transcription = 'jim - [дж] – звонкий, середина языка';

  /// Позиция буквы в алфавите: заполнение полосы под шапкой.
  final progress = 0.44;

  final forms = const [
    LetterForm(index: 1, glyph: 'ج', title: 'обособленная'),
    LetterForm(index: 2, glyph: 'جـ', title: 'начальная'),
    LetterForm(index: 3, glyph: 'ـجـ', title: 'серединная'),
    LetterForm(index: 4, glyph: 'ـج', title: 'конечная'),
  ];

  final tajweedTitle = 'Таджвид · Калькаля';
  final tajweedText = 'Если буква ج стоит с сукуном, она произносится '
      'с лёгким «отскоком» — калькалей. Звук короткий и упругий, '
      'без гласного призвука.';

  final nextTitle = 'Далее';
  final nextSubtitle = 'Буква “джим”';

  void onBack() => Get.back();

  void onPlay() {}

  void onNext() {}
}
