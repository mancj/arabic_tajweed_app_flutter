import 'dart:async';

import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/connection_build_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/data/lesson_audio.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/connected_build_answer.dart';
import 'package:flutter/material.dart';

import 'connection_build_debug_content.dart';

/// Самостоятельное упражнение, без планировщика и журнала ответов курса.
class ConnectionBuildDebugPage extends StatefulWidget {
  static const routeName = '/debug/connection-build';

  const ConnectionBuildDebugPage({this.audio, this.questions, super.key});

  final LessonAudio? audio;
  final List<ConnectionBuildQuestion>? questions;

  @override
  State<ConnectionBuildDebugPage> createState() =>
      _ConnectionBuildDebugPageState();
}

class _ConnectionBuildDebugPageState extends State<ConnectionBuildDebugPage> {
  late final LessonAudio _audio = widget.audio ?? LetterAudio();
  final _scroll = ScrollController();
  List<ConnectionBuildQuestion> _questions = const [];
  int _index = 0;
  int _round = 0;
  String? _error;
  ConnectedBuildAnswer? _answer;
  String? get _formId => _answer?.formIds.single;
  String? get _markId => _answer?.markIds.single;
  ConnectionBuildEvaluation? get _evaluation => _answer?.connectionEvaluation;

  ConnectionBuildQuestion? get _question =>
      _questions.isEmpty ? null : _questions[_index];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final questions =
          widget.questions ?? await loadConnectionBuildDebugQuestions();
      if (questions.isEmpty) throw StateError('Нет примеров');
      if (mounted) {
        setState(() {
          _questions = questions;
          _answer = ConnectedBuildAnswer.connection(_question!);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить соединения');
    }
  }

  void _selectForm(String id) {
    final question = _question;
    if (question == null ||
        _evaluation != null ||
        !question.formOptions.any((atom) => atom.id == id)) {
      return;
    }
    final enteringMarkStep = _formId == null && _markId == null;
    setState(() => _answer!.selectForm(0, id));
    if (enteringMarkStep) {
      unawaited(_audio.playAsset(question.audioAsset));
      _revealBottom();
    }
    if (_markId != null) _check();
  }

  void _selectMark(String id) {
    if (_evaluation != null ||
        _formId == null ||
        !HarakaSyllables.marks.any((mark) => mark.id == id)) {
      return;
    }
    setState(() => _answer!.selectMark(0, id));
    _check();
  }

  void _check() {
    final question = _question;
    if (question == null || _formId == null || _markId == null) {
      return;
    }
    unawaited(_audio.stop());
    _revealBottom();
  }

  void _retry() {
    final result = _evaluation;
    if (result == null || result.correct) return;
    setState(() => _answer!.retry());
    unawaited(_audio.playAsset(_question!.audioAsset));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (_evaluation?.correct != true) return;
    unawaited(_audio.stop());
    setState(() {
      _index = (_index + 1) % _questions.length;
      _round++;
      _answer = ConnectedBuildAnswer.connection(_question!);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
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
      title: 'Сборка связки',
      bottomBar: _evaluation == null
          ? null
          : NextButton(
              title: _evaluation!.correct
                  ? 'Следующее задание'
                  : 'Попробовать ещё раз',
              onTap: _evaluation!.correct ? _next : _retry,
            ),
      builder: (_, insets) => SingleChildScrollView(
        controller: _scroll,
        padding: insets,
        child: _error != null
            ? RuleCard(title: _error!)
            : question == null
            ? const Center(child: CircularProgressIndicator())
            : ConnectionBuildExercise(
                key: ValueKey('connection-build-$_round'),
                question: question,
                selectedFormId: _formId,
                selectedMarkId: _markId,
                evaluation: _evaluation,
                onFormSelected: _selectForm,
                onMarkSelected: _selectMark,
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
