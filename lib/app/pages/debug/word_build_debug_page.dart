import 'dart:async';

import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/word_build_exercise.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/connected_build_answer.dart';
import 'package:arabic_tajweed_app/domain/word_build_question.dart';
import 'package:flutter/material.dart';

import 'connection_build_debug_content.dart';

/// Просмотр задания без планировщика и журнала ответов курса.
class WordBuildDebugPage extends StatefulWidget {
  static const routeName = '/debug/word-build';

  const WordBuildDebugPage({this.audio, this.questions, super.key});

  final LessonAudio? audio;
  final List<WordBuildQuestion>? questions;

  @override
  State<WordBuildDebugPage> createState() => _WordBuildDebugPageState();
}

class _WordBuildDebugPageState extends State<WordBuildDebugPage> {
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  final _scroll = ScrollController();
  List<WordBuildQuestion> _questions = const [];
  ConnectedBuildAnswer? _answer;
  List<String?> get _formIds => _answer?.formIds ?? const [];
  List<String?> get _markIds => _answer?.markIds ?? const [];
  int _index = 0;
  int _round = 0;
  int? get _changedIndex => _answer?.changedIndex;
  String? _error;
  WordBuildEvaluation? get _evaluation => _answer?.wordEvaluation;

  WordBuildQuestion? get _question =>
      _questions.isEmpty ? null : _questions[_index];
  WordBuildPhase get _phase => _answer?.phase ?? WordBuildPhase.forms;
  int get _activeIndex => _answer?.activeIndex ?? 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final questions = widget.questions ?? await loadWordBuildDebugQuestions();
      if (questions.isEmpty) throw StateError('Нет примеров');
      if (mounted) {
        setState(() {
          _questions = questions;
          _resetAnswer();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить слова');
    }
  }

  void _resetAnswer() {
    _answer = ConnectedBuildAnswer.word(_question!);
  }

  // Номер места и раунд захвачены при показе плиток. Повторный быстрый
  // тап по старой плитке не должен заполнить следующую букву или знак.
  void _selectForm(int round, int index, String id) {
    final question = _question;
    if (!mounted ||
        question == null ||
        round != _round ||
        _evaluation != null ||
        _phase != WordBuildPhase.forms ||
        index != _activeIndex ||
        !question.steps[index].formOptions.any((form) => form.id == id)) {
      return;
    }
    setState(() {
      _answer!.selectForm(index, id);
    });
    _afterSelection(WordBuildPhase.forms);
  }

  void _selectMark(int round, int index, String id) {
    if (!mounted ||
        _question == null ||
        round != _round ||
        _evaluation != null ||
        _phase != WordBuildPhase.marks ||
        index != _activeIndex ||
        !HarakaSyllables.marks.any((mark) => mark.id == id)) {
      return;
    }
    setState(() {
      _answer!.selectMark(index, id);
    });
    _afterSelection(WordBuildPhase.marks);
  }

  void _afterSelection(WordBuildPhase previousPhase) {
    if (_evaluation != null) {
      unawaited(_audio.stop());
      _revealBottom();
    } else if (previousPhase == WordBuildPhase.forms &&
        _phase == WordBuildPhase.marks) {
      unawaited(_audio.playAsset(_question!.audioAsset));
    }
  }

  void _retry(int round) {
    final result = _evaluation;
    if (!mounted || round != _round || result == null || result.correct) return;
    setState(() => _answer!.retry());
    unawaited(_audio.playAsset(_question!.audioAsset));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next(int round) {
    if (!mounted || round != _round || _evaluation?.correct != true) return;
    setState(() {
      _index = (_index + 1) % _questions.length;
      _round++;
      _resetAnswer();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _revealBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    });
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
    final result = _evaluation;
    final round = _round;
    final activeIndex = _activeIndex;
    return AppScaffold(
      title: 'Сборка слова',
      bottomBar: result == null
          ? null
          : NextButton(
              title: result.correct ? 'Следующее слово' : 'Попробовать ещё раз',
              onTap: result.correct ? () => _next(round) : () => _retry(round),
            ),
      builder: (_, insets) => SingleChildScrollView(
        controller: _scroll,
        padding: insets,
        child: _error != null
            ? RuleCard(title: _error!)
            : question == null
            ? const Center(child: CircularProgressIndicator())
            : WordBuildExercise(
                key: ValueKey('word-build-$round'),
                question: question,
                phase: _phase,
                activeIndex: activeIndex,
                formIds: List.unmodifiable(_formIds),
                markIds: List.unmodifiable(_markIds),
                evaluation: result,
                animatedIndex: _changedIndex,
                onFormSelected: (id) => _selectForm(round, activeIndex, id),
                onMarkSelected: (id) => _selectMark(round, activeIndex, id),
                onPlay: () =>
                    unawaited(_audio.toggleAsset(question.audioAsset)),
                onAutoPlay: () =>
                    unawaited(_audio.playAsset(question.audioAsset)),
                track: _audio.track,
              ),
      ),
    );
  }
}
