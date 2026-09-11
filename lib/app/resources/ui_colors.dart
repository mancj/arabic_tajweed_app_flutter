import 'package:flutter/material.dart';

/// Цветовые токены интерфейса из референса.
///
/// Статические геттеры берут палитру по системной яркости, поэтому при смене
/// темы устройства уже построенные виджеты получают новые цвета автоматически.
class UIColors {
  const UIColors._();

  static const light = UIColorPalette(
    pageBackground: Color(0xFFECECEC),
    secondary1: Color(0xFF8C92A2),
    secondary2: Color(0xFF6F7F91),
    primary: Color(0xFFEE7740),
    primary10: Color(0x1AEE7740),
    primary20: Color(0x33EE7740),
    primary30: Color(0x4DEE7740),
    primary40: Color(0x66EE7740),
    primary50: Color(0x80EE7740),
    primary60: Color(0x99EE7740),
    primary70: Color(0xB3EE7740),
    primary80: Color(0xCCEE7740),
    primary90: Color(0xE6EE7740),
    backgroundShapes2: Color.fromARGB(255, 231, 231, 231),
    backgroundShapes1: Color.fromARGB(255, 231, 231, 231),
    text: Color(0xFF0C233E),
    cardBackground: Color(0xFFF7F7F7),
    highlightArea: Color(0xFFFFFFFF),
    borders: Color(0xFFFFFFFF),
    shadows: Color(0x0D0C233E),
    primaryButtonBottom: Color(0xFFE36024),
    primaryButtonHighlight: Color(0xFFE66E37),
    primaryButtonShadow: Color(0xFFA04823),
    circleButtonBottom: Color(0xFFF19D77),
    badgeText1: Color(0xFFFFFFFF),
    badgeText2: Color(0xFF0C233E),
  );

  static const dark = UIColorPalette(
    pageBackground: Color(0xFF0C1724),
    secondary1: Color(0xFF8990A0),
    secondary2: Color(0xFF627182),
    primary: Color(0xFFEE7740),
    primary10: Color(0x1AEE7740),
    primary20: Color(0x33EE7740),
    primary30: Color(0x4DEE7740),
    primary40: Color(0x66EE7740),
    primary50: Color(0x80EE7740),
    primary60: Color(0x99EE7740),
    primary70: Color(0xB3EE7740),
    primary80: Color(0xCCEE7740),
    primary90: Color(0xE6EE7740),
    backgroundShapes2: Color(0xFF1C3553),
    backgroundShapes1: Color(0xFF223B5B),
    text: Color(0xFFFFFFFF),
    cardBackground: Color(0xFF132235),
    highlightArea: Color(0xFF183252),
    borders: Color(0xFF243A54),
    shadows: Color(0x0D0C233E),
    primaryButtonBottom: Color(0xFFE36024),
    primaryButtonHighlight: Color(0xFFE66E37),
    primaryButtonShadow: Color(0xFFA04823),
    circleButtonBottom: Color(0xFFF19D77),
    badgeText1: Color(0xFF0C233E),
    badgeText2: Color(0xFFFFFFFF),
  );

  static UIColorPalette get _active =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      ? dark
      : light;

  static Color get pageBackground => _active.pageBackground;
  static Color get secondary1 => _active.secondary1;
  static Color get secondary2 => _active.secondary2;
  static Color get primary => _active.primary;
  static Color get primary10 => _active.primary10;
  static Color get primary20 => _active.primary20;
  static Color get primary30 => _active.primary30;
  static Color get primary40 => _active.primary40;
  static Color get primary50 => _active.primary50;
  static Color get primary60 => _active.primary60;
  static Color get primary70 => _active.primary70;
  static Color get primary80 => _active.primary80;
  static Color get primary90 => _active.primary90;
  static Color get backgroundShapes2 => _active.backgroundShapes2;
  static Color get backgroundShapes1 => _active.backgroundShapes1;
  static Color get text => _active.text;
  static Color get cardBackground => _active.cardBackground;
  static Color get highlightArea => _active.highlightArea;
  static Color get borders => _active.borders;
  static Color get shadows => _active.shadows;
  static Color get primaryButtonBottom => _active.primaryButtonBottom;
  static Color get primaryButtonHighlight => _active.primaryButtonHighlight;
  static Color get primaryButtonShadow => _active.primaryButtonShadow;
  static Color get circleButtonBottom => _active.circleButtonBottom;
  static Color get badgeText1 => _active.badgeText1;
  static Color get primaryButtonText => _active.primaryButtonText;
  static Color get badgeText2 => _active.badgeText2;
  static Color get white10 => _active.white10;
  static Color get white20 => _active.white20;
  static Color get white30 => _active.white30;
  static Color get white40 => _active.white40;
  static Color get white50 => _active.white50;
  static Color get white60 => _active.white60;
  static Color get white70 => _active.white70;
  static Color get white80 => _active.white80;
  static Color get white90 => _active.white90;
  static Color get white => _active.white;

  /// Служебная прозрачность: это не цветовой токен интерфейса.
  static const transparent = Color(0x00000000);
}

class UIColorPalette {
  final Color pageBackground;
  final Color secondary1;
  final Color secondary2;
  final Color primary;
  final Color primary10;
  final Color primary20;
  final Color primary30;
  final Color primary40;
  final Color primary50;
  final Color primary60;
  final Color primary70;
  final Color primary80;
  final Color primary90;
  final Color backgroundShapes2;
  final Color backgroundShapes1;
  final Color text;
  final Color cardBackground;
  final Color highlightArea;
  final Color borders;
  final Color shadows;
  final Color primaryButtonBottom;
  final Color primaryButtonHighlight;
  final Color primaryButtonShadow;
  final Color circleButtonBottom;
  final Color primaryButtonText = const Color(0xFFFFFFFF);
  final Color badgeText1;
  final Color badgeText2;
  final Color white10 = const Color(0x1AFFFFFF);
  final Color white20 = const Color(0x33FFFFFF);
  final Color white30 = const Color(0x4DFFFFFF);
  final Color white40 = const Color(0x66FFFFFF);
  final Color white50 = const Color(0x80FFFFFF);
  final Color white60 = const Color(0x99FFFFFF);
  final Color white70 = const Color(0xB3FFFFFF);
  final Color white80 = const Color(0xCCFFFFFF);
  final Color white90 = const Color(0xE6FFFFFF);
  final Color white = const Color(0xFFFFFFFF);

  const UIColorPalette({
    required this.pageBackground,
    required this.secondary1,
    required this.secondary2,
    required this.primary,
    required this.primary10,
    required this.primary20,
    required this.primary30,
    required this.primary40,
    required this.primary50,
    required this.primary60,
    required this.primary70,
    required this.primary80,
    required this.primary90,
    required this.backgroundShapes2,
    required this.backgroundShapes1,
    required this.text,
    required this.cardBackground,
    required this.highlightArea,
    required this.borders,
    required this.shadows,
    required this.primaryButtonBottom,
    required this.primaryButtonHighlight,
    required this.primaryButtonShadow,
    required this.circleButtonBottom,
    required this.badgeText1,
    required this.badgeText2,
  });
}
