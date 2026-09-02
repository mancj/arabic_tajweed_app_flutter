import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

class UITextStyles {
  /// Основной шрифт интерфейса.
  static const fontOnest = 'Onest';

  /// Акцентный шрифт для заголовков.
  static const fontPrata = 'Prata';

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
    color: UIColors.ink,
    fontFamily: fontOnest,
  );

  static const regularText = TextStyle(
    color: UIColors.ink,
    fontSize: 17,
    fontFamily: fontOnest,
  );

  static const regularTextDark = TextStyle(
    color: UIColors.black,
    fontSize: 17,
    fontFamily: fontOnest,
  );
  static const semiboldText = TextStyle(
    color: UIColors.ink,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  static const regular17 = TextStyle(
    color: UIColors.text,
    fontSize: 17,
    fontFamily: fontOnest,
  );
  static const hint = TextStyle(
    color: UIColors.secondary3,
    fontSize: 15,
    fontFamily: fontOnest,
  );

  static const tab = TextStyle(
    color: UIColors.secondary3,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  static const tabSelected = TextStyle(
    color: UIColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  /// Плашка «Новая тема» на карточке правила.
  static const badge = TextStyle(
    color: UIColors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontOnest,
  );

  /// Заголовок карточки с правилом.
  static const cardTitle = TextStyle(
    color: UIColors.ink,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontFamily: fontOnest,
  );

  /// Тело правила: в макете набрано засечками, кегль и интерлиньяж оттуда же.
  static const ruleBody = TextStyle(
    color: UIColors.black,
    fontSize: 16,
    height: 1.5,
    fontFamily: fontPrata,
  );

  static const semibold17 = TextStyle(
    color: UIColors.text,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    fontFamily: fontOnest,
  );
}
