import 'dart:async';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/mono_text_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/segmented_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_pronunciation_exercise.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/pronunciation_checker.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'haraka_debug_content.dart';

/// Запись отправляется на /syllable; учебный прогресс не изменяется.
class SyllablePronunciationDebugPage extends StatefulWidget {
  static const routeName = '/debug/syllable-pronunciation';

  const SyllablePronunciationDebugPage({
    this.checker,
    this.audio,
    this.syllables,
    super.key,
  });

  final PronunciationChecker? checker;
  final LessonAudio? audio;
  final List<Atom>? syllables;

  @override
  State<SyllablePronunciationDebugPage> createState() =>
      _SyllablePronunciationDebugPageState();
}

class _SyllablePronunciationDebugPageState
    extends State<SyllablePronunciationDebugPage> {
  late final PronunciationChecker _checker =
      widget.checker ?? PronunciationChecker();
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  List<List<Atom>> _families = const [];
  int _letter = 0;
  int _mark = 0;
  bool _starting = false;
  String? _expected;
  String? _loadError;

  bool get _busy =>
      _checker.isRecording.value || _checker.isChecking.value || _starting;
  Atom? get _atom => _families.isEmpty ? null : _families[_letter][_mark];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final syllables = widget.syllables ?? await loadHarakaDebugSyllables();
      final families = syllables
          .groupListsBy((atom) => atom.letterId)
          .values
          .where((family) => family.length == 3)
          .map(
            (family) => family.sortedBy(
              (atom) => HarakaSyllables.marks.indexWhere(
                (mark) => mark.id == HarakaSyllables.markIdFor(atom),
              ),
            ),
          )
          .toList();
      if (families.isEmpty) throw StateError('Нет слогов');
      if (!mounted) return;
      setState(() {
        _families = families;
        final ba = families.indexWhere(
          (family) => family.first.letterId == 'ba',
        );
        _letter = ba < 0 ? 0 : ba;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Не удалось загрузить слоги');
    }
  }

  void _select({int? letter, int? mark}) {
    if (_busy) return;
    unawaited(_audio.stop());
    _checker.reset();
    setState(() {
      _letter = letter ?? _letter;
      _mark = mark ?? _mark;
    });
  }

  Future<void> _startRecording() async {
    if (_busy || _atom == null) return;
    setState(() => _starting = true);
    _expected = _atom!.display;
    _checker.reset();
    try {
      await _audio.stop();
      if (mounted) await _checker.start();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_expected case final expected?) {
      await _checker.stopSyllable(expected: expected);
    }
  }

  @override
  void dispose() {
    _checker.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Чтение слога вслух',
    bottomBar: Obx(
      () => PronunciationRecorderWidget(
        state: _checker.isChecking.value
            ? PronunciationRecorderState.checking
            : _checker.isRecording.value
            ? PronunciationRecorderState.recording
            : PronunciationRecorderState.idle,
        level: _checker.level,
        onRecordPressed: _atom == null || _starting || _checker.isChecking.value
            ? null
            : () => unawaited(_startRecording()),
        onStopPressed: () => unawaited(_stopRecording()),
        microphonePermissionDenied:
            _checker.failure.value == PronunciationFailureKind.microphoneDenied,
        microphoneSettingsRequired: _checker.microphoneSettingsRequired.value,
        onOpenSettings: _checker.openMicrophoneSettings,
      ),
    ),
    builder: (_, insets) => SingleChildScrollView(
      padding: insets,
      child: _loadError != null
          ? RuleCard(title: _loadError!)
          : _atom == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(
                  () => SyllablePronunciationExercise(
                    glyph: _atom!.display,
                    result: _checker.syllableResult.value,
                    error:
                        _checker.failure.value ==
                            PronunciationFailureKind.microphoneDenied
                        ? null
                        : _checker.error.value,
                  ),
                ),
                const Margin.vertical(24),
                Text('БУКВА', style: UITextStyles.monoSemibold11),
                const Margin.vertical(8),
                Obx(
                  () => IgnorePointer(
                    ignoring: _busy,
                    child: LetterTabs(
                      glyphs: _families
                          .map(
                            (family) =>
                                HarakaSyllables.bareGlyphFor(family.first),
                          )
                          .toList(),
                      selected: _letter,
                      onChanged: (index) => _select(letter: index),
                    ),
                  ),
                ),
                const Margin.vertical(16),
                Text('ОГЛАСОВКА', style: UITextStyles.monoSemibold11),
                const Margin.vertical(8),
                Obx(
                  () => IgnorePointer(
                    ignoring: _busy,
                    child: SegmentedTabs(
                      labels: const ['Фатха', 'Касра', 'Дамма'],
                      selected: _mark,
                      onChanged: (index) => _select(mark: index),
                    ),
                  ),
                ),
                Obx(
                  () => _checker.syllableResult.value == null
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            const Margin.vertical(16),
                            MonoTextButton(
                              title: 'Послушать образец',
                              icon: Icons.volume_up_rounded,
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(
                                      _audio.toggleAsset(_atom!.audioAsset),
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    ),
  );
}
