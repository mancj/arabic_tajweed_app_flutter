import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

class UITextStyles {
  /// Основной шрифт интерфейса.
  static const fontOnest = 'Onest';

  /// Акцентный шрифт для заголовков.
  static const fontSerif = 'STIXTwoText';

  /// Шрифт для арабского текста.
  static const fontScheherazadeNew = 'ScheherazadeNew';

  /// Дополнительный шрифт для арабского текста.
  static const fontDGFaseh = 'DGFaseh';

  /// Моноширинный шрифт для технических значений и чисел.
  static const fontJetBrainsMono = 'JetBrainsMono';

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

  static TextStyle _style({
    required double size,
    String family = fontOnest,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    List<String>? fallback,
    List<FontVariation>? variations,
  }) => TextStyle(
    color: UIColors.text,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontVariations: variations,
  );

  /// Масштабирует готовый токен вместе с фиксированной макетной карточкой.
  static TextStyle scaled(TextStyle style, double factor) =>
      style.copyWith(fontSize: style.fontSize! * factor);

  // Onest — основной шрифт интерфейса.
  static TextStyle get regular10Compact => _style(size: 10, height: 1);
  static TextStyle get regular11 => _style(size: 11);
  static TextStyle get regular11Relaxed => _style(size: 11, height: 1.5);
  static TextStyle get regular12 => _style(size: 12);
  static TextStyle get regular13 => _style(size: 13);
  static TextStyle get regular15 => _style(size: 15);
  static TextStyle get regular17 => _style(size: 17);

  static TextStyle get medium15 => _style(size: 15, weight: FontWeight.w500);
  static TextStyle get medium22 => _style(size: 22, weight: FontWeight.w500);

  static TextStyle get semibold12 => _style(size: 12, weight: FontWeight.w600);
  static TextStyle get semibold13 =>
      _style(size: 13, weight: FontWeight.w600, height: 1.2);
  static TextStyle get semibold14 => _style(size: 14, weight: FontWeight.w600);
  static TextStyle get semibold14Relaxed =>
      _style(size: 14, weight: FontWeight.w600, height: 1.25);
  static TextStyle get semibold15 => _style(size: 15, weight: FontWeight.w600);
  static TextStyle get semibold16 => _style(size: 16, weight: FontWeight.w600);
  static TextStyle get semibold16Compact =>
      _style(size: 16, weight: FontWeight.w600, height: 1.2);
  static TextStyle get semibold17 => _style(size: 17, weight: FontWeight.w600);
  static TextStyle get semibold20 => _style(size: 20, weight: FontWeight.w600);
  static TextStyle get semibold22 =>
      _style(size: 22, weight: FontWeight.w600, fallback: const [fontDGFaseh]);
  static TextStyle get semibold22Compact => _style(
    size: 22,
    weight: FontWeight.w600,
    height: 1.1,
    fallback: const [fontDGFaseh],
  );
  static TextStyle get semibold27 => _style(
    size: 27,
    weight: FontWeight.w600,
    height: 1.12,
    letterSpacing: -.6,
    fallback: const [fontDGFaseh],
  );
  static TextStyle get semibold28 => _style(size: 28, weight: FontWeight.w600);
  static TextStyle get semibold29 => _style(
    size: 29,
    weight: FontWeight.w600,
    height: 1.16,
    letterSpacing: -.8,
  );
  static TextStyle get semibold32 => _style(size: 32, weight: FontWeight.w600);

  static TextStyle get bold17 => _style(size: 17, weight: FontWeight.w700);

  // JetBrains Mono — технические значения, подписи и числа.
  static TextStyle get monoRegular11 =>
      _style(size: 11, family: fontJetBrainsMono);
  static TextStyle get monoRegular12 =>
      _style(size: 12, family: fontJetBrainsMono);
  static TextStyle get monoRegular14 =>
      _style(size: 14, family: fontJetBrainsMono);
  static TextStyle get monoMedium12 =>
      _style(size: 12, family: fontJetBrainsMono, weight: FontWeight.w500);
  static TextStyle get monoSemibold11 => _style(
    size: 11,
    family: fontJetBrainsMono,
    weight: FontWeight.w600,
    letterSpacing: .8,
  );
  static TextStyle get monoSemibold13 =>
      _style(size: 13, family: fontJetBrainsMono, weight: FontWeight.w600);
  static TextStyle get monoSemibold14 =>
      _style(size: 14, family: fontJetBrainsMono, weight: FontWeight.w600);

  // STIX Two Text — текст с засечками.
  static TextStyle get serifRegular16 =>
      _style(size: 16, family: fontSerif, height: 1.5);
  static TextStyle get serifRegular17 => _style(size: 17, family: fontSerif);
  static TextStyle get serifRegular32Compact =>
      _style(size: 32, family: fontSerif, height: 1);
  static TextStyle get serifSemibold18Compact =>
      _style(size: 18, family: fontSerif, weight: FontWeight.w600, height: 1);

  // Playfair — акцентный текст с засечками.
  static TextStyle get playfairMedium14 =>
      _style(size: 14, family: fontPlayfair, variations: playfair(500));
  static TextStyle get playfairMedium18 => _style(
    size: 18,
    family: fontPlayfair,
    height: 1.1228,
    fallback: const [fontScheherazadeNew],
    variations: playfair(500),
  );
  static TextStyle get playfairBold18 => _style(
    size: 18,
    family: fontPlayfair,
    height: 1.1228,
    fallback: const [fontScheherazadeNew],
    variations: playfair(700),
  );

  // Учебные глифы могут получать размер из геометрии виджета.
  static TextStyle arabicRegular(double size, {double? height}) =>
      _style(size: size, family: fontScheherazadeNew, height: height);
  static TextStyle arabicMedium(double size, {double? height}) => _style(
    size: size,
    family: fontScheherazadeNew,
    weight: FontWeight.w500,
    height: height,
  );
  static TextStyle dgFasehRegular(double size, {double? height}) =>
      _style(size: size, family: fontDGFaseh, height: height);

  // Scheherazade New — арабский учебный текст фиксированного размера.
  static TextStyle get arabicRegular16 => arabicRegular(16);
  static TextStyle get arabicRegular22 => arabicRegular(22);
  static TextStyle get arabicRegular32 => arabicRegular(32);
  static TextStyle get arabicRegular38Compact => arabicRegular(38, height: 1);
  static TextStyle get arabicRegular48Compact => arabicRegular(48, height: 1);
  static TextStyle get arabicRegular64 => arabicRegular(64);
  static TextStyle get arabicRegular80Compact => arabicRegular(80, height: 1);
}
