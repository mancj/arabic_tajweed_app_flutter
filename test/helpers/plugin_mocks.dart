import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подменяет каналы плагинов, которых в тестах нет: сенсоры для наклона
/// карточки, плеер озвучки и плагин волны. Все отвечают молчанием, а без
/// подмены каждый бросает MissingPluginException и валит тест уже после
/// того, как тот прошёл.
///
/// Плеер обязан быть создан с именем [playerId]: у настоящего имя случайное,
/// и его канал событий подменить нечем.
void mockPlatformPlugins({String playerId = 'test'}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'dev.fluttercommunity.plus/sensors/gyroscope',
    'dev.fluttercommunity.plus/sensors/accelerometer',
    'dev.fluttercommunity.plus/sensors/user_accel',
    'dev.fluttercommunity.plus/sensors/magnetometer',
    'xyz.luan/audioplayers.global/events',
    'xyz.luan/audioplayers/events/$playerId',
  ]) {
    messenger.setMockStreamHandler(
      EventChannel(channel),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  }
  for (final channel in [
    'dev.fluttercommunity.plus/sensors/method',
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'simform_audio_waveforms_plugin/methods',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (_) async => null,
    );
  }
}
