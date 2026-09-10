import 'package:flutter/material.dart';

/// Цветовые токены интерфейса из референса.
///
/// В приложении используются только названия токенов ниже. [light] и [dark]
/// хранят обе колонки референса; статические поля — активная светлая тема,
/// которую используют существующие виджеты.
class UIColors {
  const UIColors._();

  static const pageBackground = Color(0xFFECECEC);
  static const secondary1 = Color(0xFF8A91A4);
  static const secondary2 = Color(0xFF6F7F91);
  static const primary = Color(0xFFEE7740);
  static const primary40 = Color(0x66EE7740);
  static const primary20 = Color(0x33EE7740);
  static const backgroundShapes2 = Color(0xFFDDDDDD);
  static const backgroundShapes1 = Color(0xFFE3E3E3);
  static const text = Color(0xFF0C233E);
  static const cardBackground = Color(0xFFF7F7F7);
  static const highlightArea = Color(0xFFFFFFFF);
  static const borders = Color(0xFFFFFFFF);
  static const shadows = Color(0x0D0C233E);

  // Точные оттенки старого оформления кнопок.
  static const primaryButtonBottom = Color(0xFFE36024);
  static const primaryButtonHighlight = Color(0xFFE66E37);
  static const primaryButtonShadow = Color(0xFFA04823);
  static const circleButtonBottom = Color(0xFFF19D77);
  static const circleButtonShadow = Color(0x37B1B1B1);

  static const light = _UIColorPalette(
    pageBackground: pageBackground,
    secondary1: secondary1,
    secondary2: secondary2,
    primary: primary,
    primary40: primary40,
    primary20: primary20,
    backgroundShapes2: backgroundShapes2,
    backgroundShapes1: backgroundShapes1,
    text: text,
    cardBackground: cardBackground,
    highlightArea: highlightArea,
    borders: borders,
  );

  static const dark = _UIColorPalette(
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
  );

  /// Служебная прозрачность: это не цветовой токен интерфейса.
  static const transparent = Color(0x00000000);
}

class _UIColorPalette {
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

  const _UIColorPalette({
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
  });
}
