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
    primary40: Color(0x66EE7740),
    primary20: Color(0x33EE7740),
    backgroundShapes2: Color(0xFFDDDDDD),
    backgroundShapes1: Color(0xFFE3E3E3),
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
    primary40: Color(0x66EE7740),
    primary20: Color(0x33EE7740),
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
  static Color get primary40 => _active.primary40;
  static Color get primary20 => _active.primary20;
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

  /// Служебная прозрачность: это не цветовой токен интерфейса.
  static const transparent = Color(0x00000000);
}

class UIColorPalette {
  final Color pageBackground;
  final Color secondary1;
  final Color secondary2;
  final Color primary;
  final Color primary40;
  final Color primary20;
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

  const UIColorPalette({
    required this.pageBackground,
    required this.secondary1,
    required this.secondary2,
    required this.primary,
    required this.primary40,
    required this.primary20,
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
