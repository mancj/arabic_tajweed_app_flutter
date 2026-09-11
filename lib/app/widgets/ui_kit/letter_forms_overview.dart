import 'package:flutter/material.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

/// Все существующие формы одной буквы на одной учебной карточке.
///
/// Первая форма стоит справа, как и другие последовательности арабского
/// письма. Порядок передаёт урок: отдельно, в конце, в начале, в середине.
class LetterFormsOverview extends StatelessWidget {
  const LetterFormsOverview({required this.forms, super.key});

  final List<Atom> forms;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final form in forms)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _FormTile(atom: form),
            ),
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
                style: UITextStyles.hint.copyWith(
                  fontFamily: UITextStyles.fontJetBrainsMono,
                  fontSize: 11,
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
                style: TextStyle(
                  color: UIColors.text,
                  fontFamily: UITextStyles.fontScheherazadeNew,
                  fontSize: 48,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
