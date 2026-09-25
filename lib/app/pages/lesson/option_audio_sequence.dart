import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/lesson_audio.dart';

/// Состояние последовательного прослушивания вариантов ответа.
class OptionPlaybackState {
  const OptionPlaybackState({this.activeIndex, this.progress = const []});

  final int? activeIndex;
  final List<double> progress;

  double progressAt(int index) => index < progress.length ? progress[index] : 0;
}

/// Проигрывает варианты по одному и связывает общий плеер с нужной карточкой.
class OptionAudioSequence {
  OptionAudioSequence({
    required LessonAudio audio,
    this.interOptionDelay = const Duration(milliseconds: 240),
  }) : _audio = audio {
    _audio.track.addListener(_onTrackChanged);
  }

  final LessonAudio _audio;
  final Duration interOptionDelay;

  final state = ValueNotifier<OptionPlaybackState>(const OptionPlaybackState());

  var _generation = 0;
  Completer<void>? _completed;
  bool _startedPlaying = false;

  Future<void> playAll(List<String?> assets) async {
    cancel();
    final generation = _generation;
    await _audio.stop();
    if (generation != _generation) return;

    state.value = OptionPlaybackState(
      progress: List<double>.filled(assets.length, 0),
    );
    for (var index = 0; index < assets.length; index++) {
      final asset = assets[index];
      if (generation != _generation) return;
      if (asset == null) continue;

      await _play(index: index, asset: asset, generation: generation);
      if (generation != _generation) return;
      _setIdle(index);
      if (index < assets.length - 1) {
        await Future<void>.delayed(interOptionDelay);
      }
    }
  }

  Future<void> toggle({required int index, required String? asset}) async {
    final wasPlaying =
        state.value.activeIndex == index && _audio.track.value.isPlaying;
    cancel();
    if (wasPlaying || asset == null) {
      await _audio.stop();
      return;
    }

    final progress = [...state.value.progress];
    if (index >= progress.length) {
      progress.addAll(List<double>.filled(index - progress.length + 1, 0));
    }
    progress[index] = 0;
    state.value = OptionPlaybackState(activeIndex: index, progress: progress);
    await _audio.playAsset(asset);
  }

  void cancel() {
    _generation++;
    final completed = _completed;
    if (completed != null && !completed.isCompleted) completed.complete();
    _completed = null;
    _setIdle();
  }

  Future<void> stop() async {
    cancel();
    await _audio.stop();
  }

  Future<void> _play({
    required int index,
    required String asset,
    required int generation,
  }) async {
    _startedPlaying = false;
    final completed = _completed = Completer<void>();
    state.value = OptionPlaybackState(
      activeIndex: index,
      progress: state.value.progress,
    );
    await _audio.playAsset(asset);
    if (generation != _generation) return;
    if (!_audio.track.value.isPlaying) completed.complete();
    await completed.future;
  }

  void _onTrackChanged() {
    final active = state.value.activeIndex;
    if (active == null) return;
    final track = _audio.track.value;
    if (track.isPlaying) _startedPlaying = true;
    _setProgress(active, track.progress);
    if (_startedPlaying && !track.isPlaying) {
      final completed = _completed;
      if (completed != null && !completed.isCompleted) {
        completed.complete();
      } else {
        _setIdle(active);
      }
    }
  }

  void _setIdle([int? index]) {
    final progress = [...state.value.progress];
    final active = index ?? state.value.activeIndex;
    if (active != null && active < progress.length) progress[active] = 0;
    _startedPlaying = false;
    state.value = OptionPlaybackState(progress: progress);
  }

  void _setProgress(int index, double value) {
    final progress = [...state.value.progress];
    if (index >= progress.length) return;
    progress[index] = value.clamp(0, 1);
    state.value = OptionPlaybackState(
      activeIndex: state.value.activeIndex,
      progress: progress,
    );
  }

  void dispose() {
    cancel();
    _audio.track.removeListener(_onTrackChanged);
    state.dispose();
  }
}
