import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Воспроизводит один короткий звуковой эффект без привязки к контроллеру.
class SingleSoundEffect {
  SingleSoundEffect({required this.assetPath, this.volume = 0.4});

  final String assetPath;
  final double volume;
  final AudioPlayer _player = AudioPlayer();
  bool _disposed = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || _disposed) return;

    try {
      await AudioCache.instance.load(assetPath);
      await _player.setReleaseMode(ReleaseMode.release);
      _player.audioCache = AudioCache.instance;
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      _initialized = true;
    } catch (error) {
      debugPrint('SingleSoundEffect init failed for $assetPath: $error');
    }
  }

  Future<void> play() async {
    if (_disposed) return;
    if (!_initialized) await init();

    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath), volume: volume);
    } catch (error) {
      debugPrint('Failed to play sound $assetPath: $error');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
