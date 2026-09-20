import 'package:flutter/foundation.dart';

import '../domain/audio_track.dart';

/// Проигрыватель записи из ассетов. Учебный материал определяет путь к ней.
abstract interface class LessonAudio {
  ValueListenable<AudioTrack> get track;
  Future<void> toggleAsset(String? asset);
  Future<void> playAsset(String? asset);
  Future<void> stop();
  Future<void> dispose();
}
