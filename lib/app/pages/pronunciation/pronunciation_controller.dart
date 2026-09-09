import 'dart:async';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/pronunciation_checker.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Тренировка произношения без урока: выбрал букву, назвал, увидел,
/// что услышал сервер. Прогресс не пишется — это стенд, а не задание.
class PronunciationController extends GetxController {
  /// Отдельные формы всех букв в порядке курикулума: имя у буквы одно,
  /// и проверять его на каждой форме незачем.
  final letters = <Atom>[].obs;
  final index = 0.obs;

  final checker = PronunciationChecker();
  final _audio = LetterAudio();

  Atom? get atom => letters.isEmpty ? null : letters[index.value];

  /// Заполнение полосы под шапкой: какая по счёту буква выбрана.
  double get progress =>
      letters.isEmpty ? 0 : (index.value + 1) / letters.length;

  bool get hasVoice => LetterAudio.has(atom?.letterId);

  void playVoice() => unawaited(_audio.toggle(atom?.letterId));

  ValueListenable<AudioTrack> get voiceTrack => _audio.track;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadLetters());
  }

  Future<void> _loadLetters() async {
    final curriculum = await const CurriculumLoader().load();
    letters.value = curriculum.nodes
        .map((node) => node.atom)
        .where((a) => a.kind == AtomKind.letterForm)
        .where((a) => a.form == LetterForm.isolated && a.letterId != null)
        .toList();
  }

  void setLetter(int value) {
    if (index.value == value) return;
    index.value = value;
    checker.reset();
  }

  Future<void> startRecording() => checker.start();

  Future<void> stopRecording() async {
    final expected = atom?.display;
    if (expected == null) return;
    await checker.stop(expected: expected);
  }

  @override
  void onClose() {
    checker.dispose();
    unawaited(_audio.dispose());
    super.onClose();
  }
}
