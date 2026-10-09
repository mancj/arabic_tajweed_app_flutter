import 'dart:async';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/mono_text_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/segmented_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_exercise.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/data/pronunciation_checker.dart';
import 'package:arabic_tajweed_app/data/rest/pronunciation_check.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/reading_word.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'haraka_debug_content.dart';

/// Запись отправляется на /pronunciation/check; учебный прогресс не изменяется.
class ReadingPronunciationDebugPage extends StatefulWidget {
  const ReadingPronunciationDebugPage({
    required this.title,
    required this.type,
    this.words,
    this.checker,
    this.audio,
    this.syllables,
    super.key,
  });

  final String title;
  final String type;
  final List<ReadingWord>? words;
  final PronunciationChecker? checker;
  final LessonAudio? audio;
  final List<Atom>? syllables;

  @override
  State<ReadingPronunciationDebugPage> createState() =>
      _ReadingPronunciationDebugPageState();
}

class _ReadingPronunciationDebugPageState
    extends State<ReadingPronunciationDebugPage> {
  late final PronunciationChecker _checker =
      widget.checker ?? PronunciationChecker();
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  List<List<Atom>> _families = const [];
  List<ReadingWord> _words = const [];
  int _word = 0;
  int _letter = 0;
  int _mark = 0;
  bool _starting = false;
  String? _expected;
  String? _unitId;
  String? _loadError;

  bool get _busy =>
      _checker.isRecording.value || _checker.isChecking.value || _starting;
  Atom? get _atom => _families.isEmpty ? null : _families[_letter][_mark];

  bool get _isWord => widget.type == PronunciationUnitType.word;
  String? get _display =>
      _isWord ? _words.elementAtOrNull(_word)?.display : _atom?.display;
  String? get _audioAsset =>
      _isWord ? _words.elementAtOrNull(_word)?.audioAsset : _atom?.audioAsset;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      if (_isWord) {
        final words =
            widget.words ??
            (await const CurriculumLoader().load()).wordsForSet('wordReading');
        if (words.isEmpty) throw StateError('Нет слов');
        if (mounted) setState(() => _words = words);
        return;
      }
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
      if (mounted) {
        setState(
          () => _loadError = _isWord
              ? 'Не удалось загрузить слова'
              : 'Не удалось загрузить слоги',
        );
      }
    }
  }

  void _select({int? letter, int? mark, int? word}) {
    if (_busy) return;
    unawaited(_audio.stop());
    _checker.reset();
    setState(() {
      _word = word ?? _word;
      _letter = letter ?? _letter;
      _mark = mark ?? _mark;
    });
  }

  Future<void> _startRecording() async {
    if (_busy || _display == null) return;
    setState(() => _starting = true);
    _expected = _display;
    _unitId = _isWord ? _words[_word].atomId ?? _words[_word].id : null;
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
      await _checker.stop(
        expected: expected,
        type: widget.type,
        unitId: _unitId,
      );
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
    title: widget.title,
    bottomBar: Obx(
      () => PronunciationRecorderWidget(
        state: _checker.isChecking.value
            ? PronunciationRecorderState.checking
            : _checker.isRecording.value
            ? PronunciationRecorderState.recording
            : PronunciationRecorderState.idle,
        level: _checker.level,
        onRecordPressed:
            _display == null || _starting || _checker.isChecking.value
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
          : _display == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(
                  () => PronunciationExercise(
                    glyph: _display!,
                    prompt: _isWord
                        ? 'Прочитайте это слово вслух'
                        : 'Прочитайте этот слог вслух',
                    result: _checker.result.value,
                    showRawHeard: _isWord,
                    error:
                        _checker.failure.value ==
                            PronunciationFailureKind.microphoneDenied
                        ? null
                        : _checker.error.value,
                  ),
                ),
                const Margin.vertical(24),
                if (_isWord)
                  Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'СЛОВО ${_word + 1} / ${_words.length}',
                          style: UITextStyles.monoSemibold11,
                        ),
                        const Margin.vertical(8),
                        MonoTextButton(
                          title: 'Предыдущее слово',
                          icon: Icons.chevron_left_rounded,
                          onPressed: _busy || _word == 0
                              ? null
                              : () => _select(word: _word - 1),
                        ),
                        const Margin.vertical(8),
                        MonoTextButton(
                          title: 'Следующее слово',
                          icon: Icons.chevron_right_rounded,
                          onPressed: _busy || _word == _words.length - 1
                              ? null
                              : () => _select(word: _word + 1),
                        ),
                      ],
                    ),
                  )
                else ...[
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
                ],
                Obx(
                  () => _checker.result.value == null
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
                                      _audio.toggleAsset(_audioAsset),
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
