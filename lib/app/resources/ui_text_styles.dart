import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

class UITextStyles {
  /// Основной шрифт интерфейса.
  static const fontOnest = 'Onest';

  /// Акцентный шрифт для заголовков.
  static const fontSerif = 'STIXTwoText';

  /// Шрифт для арабского текста.
  static const fontScheherazadeNew = 'ScheherazadeNew';

  /// Вариативный шрифт, которым в макете набрана крупная арабская буква.
  /// Начертание задаётся через [fontVariations] — статических файлов нет.
  static const fontRubik = 'Rubik';

  /// Вариативный шрифт заголовков-засечек (цифры, блок «Таджвид»).
  static const fontPlayfair = 'Playfair';

  /// Оси Playfair, зафиксированные в макете.
  static const _playfairAxes = [
    FontVariation('opsz', 12),
    FontVariation('wdth', 100),
  ];

  static List<FontVariation> playfair(double weight) => [
    ..._playfairAxes,
    FontVariation('wght', weight),
  ];

  static List<FontVariation> rubik(double weight) => [
    FontVariation('wght', weight),
  ];

  static const pageTitle = TextStyle(
    color: UIColors.text,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    fontFamily: fontOnest,
  );
  static const pageTitleSemibold = TextStyle(
    color: UIColors.text,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  static const buttonTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: UIColors.text,
    fontFamily: fontOnest,
  );

  static const regularText = TextStyle(
    color: UIColors.text,
    fontSize: 17,
    fontFamily: fontOnest,
  );

  static const regularTextDark = TextStyle(
    color: UIColors.text,
    fontSize: 17,
    fontFamily: fontOnest,
  );
  static const semiboldText = TextStyle(
    color: UIColors.text,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  static const regular17 = TextStyle(
    color: UIColors.text,
    fontSize: 17,
    fontFamily: fontOnest,
  );

  static const regular14 = TextStyle(
    color: UIColors.text,
    fontSize: 14,
    fontFamily: fontOnest,
  );

  static const regular12 = TextStyle(
    color: UIColors.text,
    fontSize: 12,
    fontFamily: fontOnest,
  );

  static const regular10 = TextStyle(
    color: UIColors.text,
    fontSize: 10,
    fontFamily: fontOnest,
  );

  static const hint = TextStyle(
    color: UIColors.secondary2,
    fontSize: 13,
    fontFamily: fontOnest,
  );

  static const tab = TextStyle(
    color: UIColors.secondary2,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  static const tabSelected = TextStyle(
    color: UIColors.text,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  /// Плашка «Новая тема» на карточке правила.
  static const badge = TextStyle(
    color: UIColors.highlightArea,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontOnest,
  );

  /// Заголовок карточки с правилом.
  static const cardTitle = TextStyle(
    color: UIColors.text,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  /// Тело правила: в макете набрано засечками, кегль и интерлиньяж оттуда же.
  static const ruleBody = TextStyle(
    color: UIColors.text,
    fontSize: 16,
    height: 1.5,
    fontFamily: fontSerif,
  );

  /// Засечки в одну строку: интерлиньяж ужат до кегля, чтобы бокс
  /// не зависел от запасов шрифта.
  static const serifSemibold18 = TextStyle(
    color: UIColors.text,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1,
    fontFamily: fontSerif,
  );

  static const semibold17 = TextStyle(
    color: UIColors.text,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    fontFamily: fontOnest,
  );
}
