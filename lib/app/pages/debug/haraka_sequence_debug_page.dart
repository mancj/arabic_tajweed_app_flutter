import 'dart:async';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';

/// Просмотр звуковой раскладки без записи учебного прогресса.
class HarakaSequenceDebugPage extends StatefulWidget {
  static const routeName = '/debug/haraka-sequence';

  const HarakaSequenceDebugPage({this.audio, super.key});

  final LessonAudio? audio;

  @override
  State<HarakaSequenceDebugPage> createState() =>
      _HarakaSequenceDebugPageState();
}

class _HarakaSequenceDebugPageState extends State<HarakaSequenceDebugPage> {
  static const _sounds = [
    Atom(
      id: 'debug.ba.fatha',
      kind: AtomKind.haraka,
      display: 'بَ',
      label: 'Ба с фатхой',
      letterId: 'ba',
      audioAsset: 'audio/harakat/ba_fatha.mp3',
    ),
    Atom(
      id: 'debug.ba.kasra',
      kind: AtomKind.haraka,
      display: 'بِ',
      label: 'Ба с касрой',
      letterId: 'ba',
      audioAsset: 'audio/harakat/ba_kasra.mp3',
    ),
    Atom(
      id: 'debug.ba.damma',
      kind: AtomKind.haraka,
      display: 'بُ',
      label: 'Ба с даммой',
      letterId: 'ba',
      audioAsset: 'audio/harakat/ba_damma.mp3',
    ),
  ];

  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  int _round = 0;
  int _attempt = 0;
  int? _playingSlot;
  List<Atom>? _answer;
  List<bool>? _slotResults;
  List<Atom?> _initialPlaced = const [];
  bool _revealCorrectOrder = false;

  List<SequenceSlot> get _slots => [
    for (var index = 0; index < _sounds.length; index++)
      SequenceSlot(
        id: 'sound-$index',
        title: 'Звук ${index + 1}',
        expectedAtomId: _sounds[(index + _round) % _sounds.length].id,
        audioAsset: _sounds[(index + _round) % _sounds.length].audioAsset,
      ),
  ];

  List<Atom> get _options => [
    for (var index = 0; index < _sounds.length; index++)
      _sounds[(index + _round + 1) % _sounds.length],
  ];

  bool get _isCorrect =>
      _answer?.indexed.every(
        (item) => item.$2.id == _slots[item.$1].expectedAtomId,
      ) ??
      false;

  int get _correctCount =>
      _slotResults?.where((correct) => correct).length ?? 0;

  @override
  void initState() {
    super.initState();
    _audio.track.addListener(_onTrackChanged);
  }

  void _onTrackChanged() {
    if (!_audio.track.value.isPlaying && _playingSlot != null && mounted) {
      setState(() => _playingSlot = null);
    }
  }

  Future<void> _playSlot(int index) async {
    final asset = _slots[index].audioAsset;
    if (asset == null) return;
    if (_playingSlot == index && _audio.track.value.isPlaying) {
      await _audio.stop();
      return;
    }
    setState(() => _playingSlot = index);
    await _audio.playAsset(asset);
    if (mounted && !_audio.track.value.isPlaying) {
      setState(() => _playingSlot = null);
    }
  }

  void _reset() {
    unawaited(_audio.stop());
    setState(() {
      _round++;
      _attempt = 0;
      _playingSlot = null;
      _answer = null;
      _slotResults = null;
      _initialPlaced = const [];
      _revealCorrectOrder = false;
    });
  }

  void _retry() {
    unawaited(_audio.stop());
    setState(() {
      _attempt++;
      _playingSlot = null;
      _answer = null;
    });
  }

  void _complete(List<Atom> answer) {
    unawaited(_audio.stop());
    final results = [
      for (final (index, atom) in answer.indexed)
        atom.id == _slots[index].expectedAtomId,
    ];
    setState(() {
      _playingSlot = null;
      _answer = answer;
      _slotResults = results;
      _initialPlaced = [
        for (final (index, atom) in answer.indexed)
          results[index] ? atom : null,
      ];
      _revealCorrectOrder =
          !results.every((correct) => correct) && _attempt == 2;
    });
  }

  @override
  void dispose() {
    _audio.track.removeListener(_onTrackChanged);
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Огласовки по звуку',
    bottomBar: NextButton(
      title: _answer == null
          ? 'Сбросить'
          : _isCorrect
          ? 'Повторить'
          : 'Исправить',
      onTap: _answer != null && !_isCorrect ? _retry : _reset,
    ),
    builder: (_, insets) => SingleChildScrollView(
      padding: insets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Расставьте огласовки буквы «Ба»', style: UITextStyles.bold17),
          const Margin.vertical(24),
          FormSequenceExercise(
            key: ValueKey('haraka-sequence-debug-$_round-$_attempt'),
            slots: _slots,
            options: _options,
            initialPlaced: _initialPlaced,
            slotResults: _slotResults,
            revealCorrectOrder: _revealCorrectOrder,
            instruction: 'Послушайте выделенный слот и выберите огласовку',
            optionNoun: 'Огласовка',
            playingSlotIndex: _playingSlot,
            onPlaySlot: (index) => unawaited(_playSlot(index)),
            onActiveSlotChanged: (index) => unawaited(_playSlot(index)),
            onCompleted: _complete,
          ),
          const Margin.vertical(24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _answer == null
                ? Text(
                    'Результат появится после заполнения трёх слотов',
                    style: UITextStyles.regular12.copyWith(
                      color: UIColors.secondary2,
                    ),
                  )
                : Text(
                    _isCorrect ? 'Верно' : 'Правильно $_correctCount из 3',
                    style: UITextStyles.bold17.copyWith(
                      color: _isCorrect
                          ? UIColors.primary
                          : UIColors.secondary2,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
