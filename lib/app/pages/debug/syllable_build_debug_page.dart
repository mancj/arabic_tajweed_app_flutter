import 'dart:async';

import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_build_exercise.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/syllable_build_question.dart';
import 'package:flutter/material.dart';

import 'haraka_debug_content.dart';

/// Упражнение №4 для просмотра, без планировщика и журнала прогресса.
class SyllableBuildDebugPage extends StatefulWidget {
  static const routeName = '/debug/syllable-build';

  const SyllableBuildDebugPage({this.audio, this.syllables, super.key});

  final LessonAudio? audio;
  final List<Atom>? syllables;

  @override
  State<SyllableBuildDebugPage> createState() => _SyllableBuildDebugPageState();
}

class _SyllableBuildDebugPageState extends State<SyllableBuildDebugPage> {
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  final _scroll = ScrollController();
  List<Atom> _syllables = const [];
  SyllableBuildQuestion? _question;
  String? _error;
  String? _letterId;
  String? _markId;
  SyllableBuildEvaluation? _evaluation;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final syllables = widget.syllables ?? await loadHarakaDebugSyllables();
      final byId = {for (final atom in syllables) atom.id: atom};
      final demoIds = ['vowel.ra.kasra', 'vowel.zay.fatha', 'vowel.dal.fatha'];
      final question = demoIds.every(byId.containsKey)
          ? SyllableBuildQuestion(
              prompt: byId[demoIds.first]!,
              letterOptions: demoIds.map((id) => byId[id]!).toList(),
            )
          : SyllableBuildQuestion.generate(syllables);
      if (!mounted) return;
      setState(() {
        _syllables = syllables;
        _question = question;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить слоги');
    }
  }

  void _selectLetter(String id) {
    if (_evaluation != null ||
        _question?.letterOptions.any((atom) => atom.letterId == id) != true) {
      return;
    }
    final reveal = _letterId == null;
    setState(() => _letterId = id);
    if (reveal) {
      unawaited(_audio.playAsset(_question!.prompt.audioAsset));
      _revealBottom();
    }
  }

  void _selectMark(String id) {
    if (_evaluation != null ||
        _letterId == null ||
        !HarakaSyllables.marks.any((mark) => mark.id == id)) {
      return;
    }
    setState(() => _markId = id);
    _check();
  }

  void _check() {
    if (_question == null ||
        _letterId == null ||
        _markId == null ||
        _evaluation != null) {
      return;
    }
    unawaited(_audio.stop());
    setState(
      () => _evaluation = _question!.evaluate(
        letterId: _letterId!,
        markId: _markId!,
      ),
    );
    _revealBottom();
  }

  void _revealBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _next() {
    final question = SyllableBuildQuestion.generate(_syllables);
    unawaited(_audio.stop());
    setState(() {
      _question = question;
      _letterId = null;
      _markId = null;
      _evaluation = null;
      _round++;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    unawaited(_audio.dispose());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    return AppScaffold(
      title: 'Сборка слога',
      bottomBar: _evaluation == null
          ? null
          : NextButton(title: 'Следующее задание', onTap: _next),
      builder: (_, insets) => SingleChildScrollView(
        controller: _scroll,
        padding: insets,
        child: _error != null
            ? RuleCard(title: _error!)
            : question == null
            ? const Center(child: CircularProgressIndicator())
            : SyllableBuildExercise(
                key: ValueKey('syllable-build-$_round'),
                question: question,
                selectedLetterId: _letterId,
                selectedMarkId: _markId,
                evaluation: _evaluation,
                onLetterSelected: _selectLetter,
                onMarkSelected: _selectMark,
                onPlay: () =>
                    unawaited(_audio.toggleAsset(question.prompt.audioAsset)),
                onAutoPlay: () =>
                    unawaited(_audio.playAsset(question.prompt.audioAsset)),
                track: _audio.track,
              ),
      ),
    );
  }
}
