import 'package:flutter/material.dart';

class UIColors {
  static const white = Color(0xFFFFFFFF);
  static const whiteHalf = Color(0x80FFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  static const pageBackground = Color(0xFFEEF0F9);
  static const itemBackground = Color(0xFFEAEDF8);
  static const secondary1 = Color(0xFFB6C4D6);
  static const secondary2 = Color(0xFF8BA4C3);
  static const secondary3 = Color(0xFF6F7F91);
  static const primary = Color(0xFF1858FE);
  static const primary20 = Color(0x331858FE);
  static const accent = Color(0xFFA5EB17);
  static const cardBackground = Color(0xFFF3F3F3);
  static const text = Color(0xFF0C233E);
  static const cardShadow = Color.fromARGB(55, 177, 177, 177);

  // Палитра экранов алфавита (макет Tajweed).
  static const lightGray = Color(0xFFECECEC);
  static const iceBlue = Color(0xFFDCEAEF);
  static const teal = Color(0xFF3F9DB5);
  static const tealDark = Color(0xFF156072);
  static const ink = Color(0xFF0C233E);
  static const coral = Color(0xFFE16868);
  static const steel = Color(0xFF749DA8);
  static const steelLight = Color(0xFF7CA3AD);
  static const cardBorder = Color(0x4D518997);

  static const orange = Color(0xFFEE7740);

  /// Подсветка важного: буква в слове-примере, ключевые слова вопроса.
  static const highlight = orange;
  static const orangeDark = Color(0xFFD8571C);
  static const orangeLight = Color(0xFFF19D77);

  /// Градиент кнопки «Далее»: в макете нижний стоп уходит за границу (146%),
  /// поэтому здесь цвет, в который градиент реально приходит к низу кнопки.
  static const orangeButtonBottom = Color(0xFFE36024);

  /// Светлая подсветка внутренней тени по нижнему краю кнопки.
  static const orangeInnerHighlight = Color(0xFFE66E37);

  /// Основа мягких теней под кнопкой (в макете rgba(106, 47, 22, a)).
  static const buttonShadow = Color.fromARGB(255, 160, 72, 35);

  /// Плашка «Новая тема» на карточке правила.
  static const orangeBadge = Color(0xFFE66E37);

  /// Фон карточки с правилом.
  static const ruleCardBackground = Color(0xFFF4F4F4);

  /// Карточка с вопросом и варианты ответа.
  static const questionCardBackground = Color(0xFFF3F3F3);
  static const questionCardShadow = Color(0x1AB1B1B1);
  static const optionBackground = Color(0xFFF8F8F8);
  static const optionDivider = Color(0xFFDDDDDD);
  static const ca = Color(0xFFDDDDDD);

  /// Бледные формы буквы на фоне карточки с вопросом.
  static const glyphGhost = Color(0xFFE3E3E3);

  /// Бледная буква-подсказка под обводкой.
  static const letterGhost = Color.fromARGB(255, 183, 185, 190);
  static const letterDemo = Color.fromARGB(255, 141, 143, 147);
  static const cardShadowSoft = Color(0x1A7CA3AD);
  static const cardShadowMedium = Color(0x267CA3AD);

  // Фоновый паттерн экранов алфавита.
  static const patternDot = Color.fromARGB(56, 147, 180, 189);
  static const patternNode = Color.fromARGB(88, 147, 180, 189);

  /// Холмы декоративной волны (будущий waveform аудио).
  static const waveform = Color.fromARGB(87, 0, 0, 0);

  static const primaryButtonGradient = [Color(0xFFFDCEB4), Color(0xFFFD8C8C)];
}
