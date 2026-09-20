import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/waveform_widget.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';

/// Одинаковая волна для карточек урока, привязанная к записи буквы.
class LessonAudioWaveform extends StatelessWidget {
  const LessonAudioWaveform({this.track, this.height = 150, super.key});

  final ValueListenable<AudioTrack>? track;
  final double height;

  @override
  Widget build(BuildContext context) => WaveformWidget(
    strokeWidth: .5,
    height: height,
    layers: 3,
    track: track,
    restHeight: .4,
    minBumps: 3,
    maxBumps: 4,
    particles: WaveformParticles(
      minRadius: .5,
      color: UIColors.primary,
      maxRadius: 1,
      duration: const Duration(seconds: 1),
      fadeInDuration: const Duration(milliseconds: 200),
    ),
  );
}
