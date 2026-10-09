import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/explanation_loader.dart';
import '../../../data/letter_audio.dart';
import '../../../domain/explanation_document.dart';
import '../../resources/ui_resources.dart';
import '../../../domain/atom.dart';
import 'explanation_card.dart';

/// Показывает карточку курса вне урока, где нет LessonController.
class ExplanationAssetCard extends StatefulWidget {
  const ExplanationAssetCard({
    required this.asset,
    this.badge,
    this.active = true,
    this.atom,
    super.key,
  });

  final String asset;
  final String? badge;
  final bool active;
  final Atom? atom;

  @override
  State<ExplanationAssetCard> createState() => _ExplanationAssetCardState();
}

class _ExplanationAssetCardState extends State<ExplanationAssetCard> {
  final _loader = ExplanationLoader();
  final _audio = LetterAudio();
  late Future<ExplanationContent> _content = _loadContent();

  Future<ExplanationContent> _loadContent() {
    final atom = widget.atom;
    return _loader
        .load(widget.asset)
        .then((content) => atom == null ? content : content.forAtom(atom));
  }

  @override
  void didUpdateWidget(covariant ExplanationAssetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset || oldWidget.atom != widget.atom) {
      _content = _loadContent();
    }
    if (oldWidget.active && !widget.active) unawaited(_audio.stop());
  }

  @override
  void dispose() {
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ExplanationContent>(
    future: _content,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(
          'Не удалось открыть объяснение: ${snapshot.error}',
          style: UITextStyles.regular15,
        );
      }
      final content = snapshot.data;
      if (content == null) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return ExplanationCard(
        content: content,
        badge: widget.badge,
        onPlay: (Atom atom) => unawaited(_audio.toggleAsset(atom.audioAsset)),
        hasVoice: (Atom atom) => atom.audioAsset != null,
        track: _audio.track,
      );
    },
  );
}
