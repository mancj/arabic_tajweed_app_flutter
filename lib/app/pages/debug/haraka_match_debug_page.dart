import 'dart:async';

import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_match_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_match_question.dart';
import 'package:flutter/material.dart';

import 'haraka_debug_content.dart';

/// Самостоятельный просмотр задания без журнала и планировщика уроков.
class HarakaMatchDebugPage extends StatefulWidget {
  static const routeName = '/debug/haraka-match';

  const HarakaMatchDebugPage({this.audio, this.syllables, super.key});

  final LessonAudio? audio;
  final List<Atom>? syllables;

  @override
  State<HarakaMatchDebugPage> createState() => _HarakaMatchDebugPageState();
}

class _HarakaMatchDebugPageState extends State<HarakaMatchDebugPage> {
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  List<Atom> _syllables = const [];
  HarakaMatchQuestion? _question;
  String? _error;
  final Set<String> _selected = {};
  bool _checked = false;
  int _round = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final syllables = widget.syllables ?? await loadHarakaDebugSyllables();
      if (!mounted) return;
      final byId = {for (final atom in syllables) atom.id: atom};
      final demoIds = [
        'vowel.mim.kasra',
        'vowel.ba.fatha',
        'vowel.ra.kasra',
        'vowel.kaf.fatha',
        'vowel.ba.damma',
      ];
      setState(() {
        _syllables = syllables;
        _question =
            byId.containsKey('vowel.ba.kasra') &&
                demoIds.every(byId.containsKey)
            ? HarakaMatchQuestion(
                prompt: byId['vowel.ba.kasra']!,
                options: demoIds.map((id) => byId[id]!).toList(),
              )
            : HarakaMatchQuestion.generate(syllables);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить слоги');
    }
  }

  void _toggle(String id) {
    if (_checked) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _check() {
    setState(() => _checked = true);
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
    unawaited(_audio.stop());
    setState(() {
      _question = HarakaMatchQuestion.generate(_syllables);
      _selected.clear();
      _checked = false;
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
      title: 'Одинаковая огласовка',
      bottomBar: question == null
          ? null
          : NextButton(
              title: _checked ? 'Следующее задание' : 'Проверить',
              enabled: _checked || _selected.isNotEmpty,
              onTap: _checked ? _next : _check,
            ),
      builder: (_, insets) => SingleChildScrollView(
        controller: _scroll,
        padding: insets,
        child: _error != null
            ? RuleCard(title: _error!)
            : question == null
            ? const Center(child: CircularProgressIndicator())
            : HarakaMatchExercise(
                key: ValueKey('haraka-match-$_round'),
                question: question,
                selectedIds: _selected,
                checked: _checked,
                onToggle: _toggle,
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
