import 'package:flutter/material.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

/// Все существующие формы одной буквы на одной учебной карточке.
///
/// Первая форма стоит справа, как и другие последовательности арабского
/// письма. Порядок передаёт урок: отдельно, в начале, в середине, в конце.
class LetterFormsOverview extends StatelessWidget {
  const LetterFormsOverview({required this.forms, super.key});

  final List<Atom> forms;

  @override
  Widget build(BuildContext context) {
    final examples = forms
        .where(
          (form) => form.form != LetterForm.isolated && form.example != null,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 100,
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 4,
            children: [
              for (final form in forms) Expanded(child: _FormTile(atom: form)),
            ],
          ),
        ),
        if (examples.isNotEmpty) ...[
          const Margin.vertical(24),
          Divider(height: 1, color: UIColors.backgroundShapes2),
          const Margin.vertical(8),
          Text('Примеры слов', style: UITextStyles.semibold22),
          const Margin.vertical(8),
          Text(
            'Посмотрите, как буква соединяется с соседними буквами в словах:',
            style: UITextStyles.serifRegular16,
          ),
          const Margin.vertical(8),
          SizedBox(child: _WordExamples(forms: examples)),
        ],
      ],
    );
  }
}

class _WordExamples extends StatelessWidget {
  const _WordExamples({required this.forms});

  final List<Atom> forms;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('letter-form-overview-examples'),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: SquircleBorders.squircleBorder(
        // color: UIColors.cardBackground,
        borderRadius: 16,
        cornerSmoothing: 0,
        borderSide: BorderSide(color: UIColors.backgroundShapes1),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          for (final form in forms) Expanded(child: _WordExample(atom: form)),
        ],
      ),
    );
  }
}

class _WordExample extends StatelessWidget {
  const _WordExample({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    final example = atom.example;
    if (example == null) return const SizedBox.shrink();
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          atom.form?.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: UITextStyles.monoRegular11.copyWith(
            color: UIColors.secondary2,
          ),
        ),
        const Margin.vertical(8),
        HighlightedWord(
          word: example.word,
          index: example.index,
          form: atom.form,
          fontSize: 32,
        ),
      ],
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('letter-form-overview-${atom.form?.name}'),
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.highlightArea,
        borderRadius: 16,
        cornerSmoothing: 0,
        borderSide: BorderSide(color: UIColors.backgroundShapes1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                atom.form?.title ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: UITextStyles.monoRegular11.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
            ),
          ),
          const Margin.vertical(4),
          SizedBox(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                atom.display,
                textDirection: TextDirection.rtl,
                style: UITextStyles.arabicRegular48Compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
