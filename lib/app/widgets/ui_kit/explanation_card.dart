import 'dart:async';

import 'package:arabic_tajweed_app/app/widgets/ui_kit/widget_extensions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/atom.dart';
import '../../../domain/audio_track.dart';
import '../../../domain/explanation_document.dart';
import '../../resources/ui_resources.dart';
import '../margin.dart';
import 'haraka_examples_grid.dart';
import 'highlighted_word.dart';
import 'letter_forms_overview.dart';
import 'letter_widget.dart';
import 'play_control.dart';
import 'rule_card.dart';

/// Собирает объяснение как образец буквы и единую страницу разделов.
/// Звук и переходы выполняет экран.
class ExplanationCard extends StatefulWidget {
  const ExplanationCard({
    required this.content,
    required this.onPlay,
    required this.hasVoice,
    required this.track,
    this.onAutoPlay,
    this.autoPlayLetter = false,
    this.badge,
    this.footer,
    this.onTapLink,
    super.key,
  });

  final ExplanationContent content;
  final String? badge;
  final Widget? footer;
  final ValueChanged<Atom> onPlay;
  final ValueChanged<Atom>? onAutoPlay;
  final bool autoPlayLetter;
  final bool Function(Atom) hasVoice;
  final ValueListenable<AudioTrack> track;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  State<ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<ExplanationCard> {
  static const _contentPadding = EdgeInsets.all(24);
  static const _childSpacing = 12.0;
  String? _activeId;

  @override
  void didUpdateWidget(covariant ExplanationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.track != widget.track) {
      _activeId = null;
    }
  }

  void _play(Atom atom) {
    setState(() => _activeId = atom.id);
    widget.onPlay(atom);
  }

  void _start(Atom atom) {
    setState(() => _activeId = atom.id);
    (widget.onAutoPlay ?? widget.onPlay)(atom);
  }

  void _openExternalLink(String _, String? href, String title) {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        !uri.hasAuthority) {
      return;
    }
    unawaited(_launchExternalLink(uri));
  }

  Future<void> _launchExternalLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // Плагин может не найти приложение для открытия ссылки.
    }
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = <List<MapEntry<int, ExplanationBlock>>>[];
    var ruleBlocks = <MapEntry<int, ExplanationBlock>>[];
    for (final (index, block) in widget.content.document.blocks.indexed) {
      if (_isStandaloneBlock(block)) {
        if (ruleBlocks.isNotEmpty) parts.add(ruleBlocks);
        parts.add([MapEntry(index, block)]);
        ruleBlocks = [];
      } else {
        ruleBlocks.add(MapEntry(index, block));
      }
    }
    if (ruleBlocks.isNotEmpty) parts.add(ruleBlocks);
    // Даже набор только из отдельных карточек сохраняет название и бейдж.
    if (parts.every(_isStandalonePart)) parts.insert(0, []);

    final firstRule = parts.indexWhere((part) => !_isStandalonePart(part));
    final lastRule = parts.lastIndexWhere((part) => !_isStandalonePart(part));
    final startsWithLetter =
        parts.firstOrNull?.singleOrNull?.value is ExplanationLetter;
    final children = <Widget>[];
    var pageSections = <Widget>[];
    var section = 0;

    void finishPage() {
      if (pageSections.isEmpty) return;
      children.add(
        Container(
          decoration: BoxDecoration(
            color: UIColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in pageSections.indexed) ...[
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, color: UIColors.backgroundShapes1),
                  ),
                child,
              ],
            ],
          ),
        ),
      );
      pageSections = [];
    }

    for (final (partIndex, part) in parts.indexed) {
      if (part.singleOrNull?.value case ExplanationLetter(:final letter)) {
        finishPage();
        children.add(
          _letter(
            letter,
            part.single.key,
            showTitle: startsWithLetter && partIndex == 0,
          ),
        );
      } else if (_isStandalonePart(part)) {
        pageSections.add(
          _standalone(
            part.single.value,
            part.single.key,
            number: (++section).toString().padLeft(2, '0'),
          ),
        );
      } else {
        final first = partIndex == firstRule;
        pageSections.add(
          RuleCard(
            flat: true,
            title: first
                ? (startsWithLetter ? 'Разбор' : widget.content.document.title)
                : '',
            badge: first && !startsWithLetter ? widget.badge : null,
            sectionNumber: first
                ? (++section).toString().padLeft(2, '0')
                : null,
            footer: partIndex == lastRule ? widget.footer : null,
            contentPadding: _contentPadding,
            childSpacing: _childSpacing,
            child: part.isEmpty ? null : _ruleBlocks(part),
          ),
        );
      }
    }
    finishPage();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Margin.vertical(12),
          child,
        ],
      ],
    );
  }

  bool _isStandaloneBlock(ExplanationBlock block) =>
      block is ExplanationLetter ||
      block is ExplanationMakhraj ||
      block is ExplanationSifat;

  bool _isStandalonePart(List<MapEntry<int, ExplanationBlock>> part) =>
      part.length == 1 && _isStandaloneBlock(part.single.value);

  Widget _standalone(ExplanationBlock block, int index, {String? number}) =>
      switch (block) {
        ExplanationLetter(:final letter) => _letter(letter, index),
        ExplanationMakhraj() => RuleCard(
          flat: true,
          sectionNumber: number,
          title: 'Как произнести',
          contentPadding: _contentPadding,
          childSpacing: _childSpacing,
          child: _ruleBlocks([MapEntry(index, block)]),
        ),
        ExplanationSifat() => RuleCard(
          flat: true,
          sectionNumber: number,
          title: 'Как звучит',
          contentPadding: _contentPadding,
          childSpacing: _childSpacing,
          child: _ruleBlocks([MapEntry(index, block)]),
        ),
        _ => throw StateError('Блок не является отдельной карточкой'),
      };

  Widget _ruleBlocks(List<MapEntry<int, ExplanationBlock>> blocks) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...blocks
          .map((block) => _block(block.value, block.key))
          .separator(const Margin.vertical(16))
          .toList(),
    ],
  );

  Widget _block(ExplanationBlock block, int index) => switch (block) {
    ExplanationText(:final text) => _markdown(text),
    ExplanationMakhraj(:final makhraj) => _markdown(makhraj),
    ExplanationSifat(:final sifat) => _markdown(sifat),
    ExplanationLetter(:final letter) => _letter(letter, index),
    ExplanationForms(:final forms) => LetterFormsOverview(
      forms: [
        for (final (formIndex, form) in forms.indexed)
          Atom(
            id: 'card.$index.form.$formIndex',
            kind: AtomKind.letterForm,
            display: form.glyph,
            form: form.position,
            example: form.example == null
                ? null
                : WordExample(
                    word: form.example!.text,
                    index: form.example!.highlight,
                  ),
          ),
      ],
    ),
    ExplanationWord(:final word) => _word(word),
    ExplanationExamples(:final examples) => ValueListenableBuilder<AudioTrack>(
      valueListenable: widget.track,
      builder: (_, track, _) => HarakaExamplesGrid(
        examples: [
          for (final (exampleIndex, example) in examples.indexed)
            _glyphAtom(example, 'card.$index.example.$exampleIndex'),
        ],
        activeId: _activeId,
        isPlaying: track.isPlaying,
        onPlay: _play,
        canPlay: widget.hasVoice,
        captions: {
          for (final (exampleIndex, example) in examples.indexed)
            if (example.caption case final caption?)
              'card.$index.example.$exampleIndex': caption,
        },
      ),
    ),
    ExplanationSound(:final sound) => _sound(sound, index),
  };

  Widget _markdown(String text) => MarkdownBody(
    data: text,
    onTapLink: widget.onTapLink ?? _openExternalLink,
    imageBuilder: _markdownImage,
    styleSheet: MarkdownStyleSheet(
      p: UITextStyles.regular16Relaxed,
      h1: UITextStyles.semibold22.copyWith(),
      h2: UITextStyles.semibold17,
      h3: UITextStyles.semibold17.copyWith(),
      h4: UITextStyles.semibold15.copyWith(),
      h5: UITextStyles.semibold15.copyWith(),
      h6: UITextStyles.semibold15.copyWith(),
      code: UITextStyles.monoRegular14,
      a: UITextStyles.semibold16.copyWith(
        color: UIColors.studyAccent,
        decoration: TextDecoration.underline,
      ),
      listBullet: UITextStyles.regular16,
      blockquote: UITextStyles.regular16,
      tableBody: UITextStyles.regular15,
      tableHead: UITextStyles.semibold15,
      blockSpacing: 12,
    ),
  );

  Widget _markdownImage(Uri uri, String? title, String? alt) {
    final ImageProvider<Object> provider = switch (uri.scheme) {
      'resource' => AssetImage(uri.path),
      'http' || 'https' => NetworkImage(uri.toString()),
      'data' => MemoryImage(uri.data!.contentAsBytes()),
      _ => AssetImage(uri.path),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image(
        image: provider,
        semanticLabel: alt,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Atom _glyphAtom(ExplanationGlyph glyph, String id) => Atom(
    id: id,
    kind: AtomKind.syllable,
    display: glyph.glyph,
    audioAsset: glyph.audio,
  );

  Widget _letter(ExplanationGlyph glyph, int index, {bool showTitle = false}) {
    final atom = _glyphAtom(glyph, 'card.$index.letter');
    final canPlay = widget.hasVoice(atom);
    final autoPlay =
        widget.autoPlayLetter &&
        canPlay &&
        widget.content.document.blocks.whereType<ExplanationLetter>().length ==
            1;
    return LetterWidgetCard(
      specimen: true,
      question: showTitle ? widget.content.document.title : null,
      labelText: showTitle ? widget.badge : null,
      letter: glyph.glyph,
      isArabic: true,
      subtitle: glyph.caption,
      onPlay: canPlay ? () => _play(atom) : null,
      onAutoPlay: autoPlay ? () => _start(atom) : null,
      // Несколько букв в одной YAML-карточке не запускают звук одновременно.
      autoPlay: autoPlay,
      track: _activeId == atom.id ? widget.track : null,
    );
  }

  Widget _word(ExplanationWordSample word) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: HighlightedWord(
        word: word.text,
        index: word.highlight,
        form: word.form,
        fontSize: 48,
      ),
    ),
  );

  Widget _sound(ExplanationSoundData sound, int index) {
    final atom = Atom(
      id: 'card.$index.sound',
      kind: AtomKind.syllable,
      display: sound.label,
      audioAsset: sound.audio,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sound.label, style: UITextStyles.semibold17),
          const Margin.vertical(8),
          PlayControl(
            letter: atom.id,
            onTap: () => _play(atom),
            autoPlay: false,
            track: _activeId == atom.id ? widget.track : null,
          ),
        ],
      ),
    );
  }
}
