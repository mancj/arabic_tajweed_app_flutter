import 'package:gaimon/gaimon.dart';

/// Отклик на нажатие.
///
/// `Gaimon.soft()` ничего не возвращает и роняет ошибку канала мимо
/// вызывающего: на платформе без гаптики — а в тестах платформенных
/// каналов нет вовсе — любой тап падал с MissingPluginException.
/// Поэтому поддержку спрашиваем один раз на старте и запоминаем: без
/// подтверждения канал не трогаем вообще.
class AppHaptics {
  AppHaptics._();

  static bool _supported = false;

  static Future<void> init() async {
    try {
      _supported = await Gaimon.canSupportsHaptic;
    } catch (_) {
      _supported = false;
    }
  }

  /// Самый лёгкий тик для нажатий и рисования.
  static void tick() {
    if (_supported) Gaimon.selection();
  }

  static void light() {
    if (_supported) Gaimon.light();
  }

  static void success() {
    if (_supported) Gaimon.success();
  }
}
