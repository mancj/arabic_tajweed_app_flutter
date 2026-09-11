import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Воспроизводит один короткий звуковой эффект без привязки к контроллеру.
class SingleSoundEffect {
  SingleSoundEffect({required this.assetPath, this.volume = 0.4});

  final String assetPath;
  final double volume;
  AudioPlayer? _player;
  bool _disposed = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || _disposed) return;

    try {
      await AudioCache.instance.load(assetPath);
      final player = _player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      player.audioCache = AudioCache.instance;
      await player.setAudioContext(
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
      await _player?.dispose();
      _player = null;
      debugPrint('SingleSoundEffect init failed for $assetPath: $error');
    }
  }

  Future<void> play() async {
    if (_disposed) return;
    if (!_initialized) await init();
    final player = _player;
    if (!_initialized || _disposed || player == null) return;

    try {
      await player.stop();
      await player.play(AssetSource(assetPath), volume: volume);
    } catch (error) {
      debugPrint('Failed to play sound $assetPath: $error');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _player?.dispose();
      _player = null;
    } catch (_) {}
  }
}
