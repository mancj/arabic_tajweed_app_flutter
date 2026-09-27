import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/letter_audio.dart';
import '../../../domain/atom.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../widgets/drawing/tracing_shape_svg.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/haraka_drawing_card.dart';
import '../../widgets/ui_kit/letter_tabs.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/segmented_tabs.dart';

/// Стенд всех вариантов письма огласовок на настоящем контенте курса.
class HarakaDrawingDebugPage extends StatefulWidget {
  static const routeName = '/debug/haraka-drawing';

  const HarakaDrawingDebugPage({super.key});

  @override
  State<HarakaDrawingDebugPage> createState() => _HarakaDrawingDebugPageState();
}

enum _HarakaMode { tracing, memory, sound }

extension on _HarakaMode {
  String get title => switch (this) {
    _HarakaMode.tracing => 'По контуру',
    _HarakaMode.memory => 'По памяти',
    _HarakaMode.sound => 'По звуку',
  };

  TracingMode get canvasMode => switch (this) {
    _HarakaMode.tracing => TracingMode.tracing,
    _HarakaMode.memory || _HarakaMode.sound => TracingMode.freehand,
  };
}

class _HarakaDrawingDebugPageState extends State<HarakaDrawingDebugPage> {
  static const _matcher = TracingMatcher();

  final _drawing = DrawingController();
  final _audio = LetterAudio();

  List<List<Atom>> _letters = const [];
  TracingShape? _shape;
  _HarakaMode _mode = _HarakaMode.tracing;
  int _letterIndex = 0;
  int _vowelIndex = 0;
  int _shapeRequest = 0;
  String _hint = 'Загрузка огласовок…';

  Atom? get _sample {
    if (_letters.isEmpty) return null;
    final vowels = _letters[_letterIndex];
    return vowels[_vowelIndex.clamp(0, vowels.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSamples());
  }

  Future<void> _loadSamples() async {
    final curriculum = await const CurriculumLoader().load();
    final syllables = curriculum.nodes
        .map((node) => node.atom)
        .where(
          (atom) =>
              atom.kind == AtomKind.syllable &&
              atom.letterId != null &&
              atom.tracing != null &&
              atom.audioAsset != null,
        )
        .toList();
    final groups = groupBy(syllables, (atom) => atom.letterId!).values.toList();
    if (!mounted) return;
    setState(() => _letters = groups);
    await _loadShape();
  }

  Future<void> _loadShape() async {
    final sample = _sample;
    if (sample == null) return;
    final request = ++_shapeRequest;
    final shape = await TracingShapeSvg.load(
      'assets/svg/${sample.tracing}.svg',
      id: sample.tracing!,
      label: sample.label,
    );
    if (!mounted || request != _shapeRequest) return;
    setState(() {
      _shape = shape;
      _resetHint();
    });
  }

  void _setMode(int index) {
    final mode = _HarakaMode.values[index];
    if (_mode == mode) return;
    unawaited(_audio.stop());
    setState(() {
      _mode = mode;
      _drawing.clear();
      _resetHint();
    });
  }

  void _setLetter(int index) {
    if (_letterIndex == index) return;
    unawaited(_audio.stop());
    setState(() {
      _letterIndex = index;
      _drawing.clear();
      _resetHint();
    });
  }

  void _setVowel(int index) {
    if (_vowelIndex == index) return;
    unawaited(_audio.stop());
    setState(() {
      _vowelIndex = index;
      _shape = null;
      _drawing.clear();
      _hint = 'Загрузка контура…';
    });
    unawaited(_loadShape());
  }

  void _clear() {
    _drawing.clear();
    setState(_resetHint);
  }

  void _undo() {
    _drawing.undo();
    setState(_resetHint);
  }

  void _check() {
    final result = _drawing.check();
    setState(() => _hint = _messageFor(result));
  }

  void _onChecked(TracingMatchResult result) {
    if (!result.isChecked || result.isMatch || !mounted) return;
    setState(() => _hint = _messageFor(result));
  }

  void _onProgress(TracingProgress progress) {
    if (!mounted) return;
    setState(() {
      _hint = progress.isComplete
          ? 'Огласовка готова'
          : 'Продолжайте рисовать огласовку';
    });
  }

  void _onReveal() {
    if (mounted) setState(() => _hint = 'Подсказка открыта — обведите знак');
  }

  void _resetHint() {
    _hint = switch (_mode) {
      _HarakaMode.tracing => 'Обведите огласовку по подсказке',
      _HarakaMode.memory => 'Нарисуйте огласовку по памяти',
      _HarakaMode.sound => 'Послушайте слог и дорисуйте огласовку',
    };
  }

  String _messageFor(TracingMatchResult result) => switch (result.status) {
    TracingMatchStatus.noInput => 'Сначала нарисуйте огласовку',
    TracingMatchStatus.noShape => 'Контур ещё загружается',
    TracingMatchStatus.checked when result.isMatch => 'Огласовка верна',
    TracingMatchStatus.checked => 'Форма или положение не совпали',
  };

  String _vowelTitle(Atom atom) => switch (atom.tracing?.split('/').last) {
    'fatha' => 'Фатха',
    'kasra' => 'Касра',
    'damma' => 'Дамма',
    _ => atom.label,
  };

  String _vowelActionName(Atom atom) => switch (atom.tracing?.split('/').last) {
    'fatha' => 'фатху',
    'kasra' => 'касру',
    'damma' => 'дамму',
    _ => 'огласовку',
  };

  String _questionFor(Atom atom) => switch (_mode) {
    _HarakaMode.tracing => 'Обведите ${_vowelActionName(atom)}',
    _HarakaMode.memory => 'Нарисуйте ${_vowelActionName(atom)} по памяти',
    _HarakaMode.sound => 'Послушайте и дорисуйте огласовку',
  };

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    return AppScaffold(
      title: 'Холст огласовок',
      builder: (_, insets) => SingleChildScrollView(
        padding: insets,
        child: sample == null
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Режим', style: UITextStyles.monoSemibold11),
                      const Margin.vertical(8),
                      SegmentedTabs(
                        labels: [
                          for (final mode in _HarakaMode.values) mode.title,
                        ],
                        selected: _HarakaMode.values.indexOf(_mode),
                        onChanged: _setMode,
                      ),
                      const Margin.vertical(16),
                      Text('Буква', style: UITextStyles.monoSemibold11),
                      const Margin.vertical(8),
                      LetterTabs(
                        glyphs: [
                          for (final vowels in _letters)
                            String.fromCharCode(
                              vowels.first.display.runes.first,
                            ),
                        ],
                        selected: _letterIndex,
                        onChanged: _setLetter,
                      ),
                      const Margin.vertical(16),
                      Text('Огласовка', style: UITextStyles.monoSemibold11),
                      const Margin.vertical(8),
                      SegmentedTabs(
                        labels: [
                          for (final atom in _letters[_letterIndex])
                            _vowelTitle(atom),
                        ],
                        selected: _vowelIndex,
                        onChanged: _setVowel,
                      ),
                      const Margin.vertical(16),
                      HarakaDrawingCard(
                        key: ValueKey('${sample.id}.${_mode.name}'),
                        letterId: sample.letterId!,
                        title: _questionFor(sample),
                        hint: _hint,
                        onClear: _clear,
                        onPlay: () =>
                            unawaited(_audio.toggleAsset(sample.audioAsset)),
                        onAutoPlay: () =>
                            unawaited(_audio.playAsset(sample.audioAsset)),
                        track: _audio.track,
                        playbackKey: '${sample.id}.${_mode.name}',
                        autoPlay: _mode == _HarakaMode.sound,
                        controller: _drawing,
                        matcher: _matcher,
                        mode: _mode.canvasMode,
                        shape: _shape,
                        enabled: _shape != null,
                        missesBeforeReveal: 3,
                        onProgress: _onProgress,
                        onChecked: _onChecked,
                        onReveal: _onReveal,
                        onMerged: () => setState(
                          () => _hint = 'Огласовка нарисована правильно',
                        ),
                      ),
                      const Margin.vertical(8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          MonoTextButton(
                            title: 'Отменить',
                            icon: Icons.undo_rounded,
                            onPressed: _undo,
                          ),
                          MonoTextButton(
                            title: 'Проверить',
                            icon: Icons.check_rounded,
                            onPressed: _shape == null ? null : _check,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _drawing.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }
}
