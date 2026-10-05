import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';

import 'exercise_tile.dart';

/// Общий одиночный выбор букв, форм и знаков из плиток.
class ExerciseChoiceRow extends StatelessWidget {
  const ExerciseChoiceRow({
    required this.options,
    required this.idFor,
    required this.glyphFor,
    required this.labelFor,
    required this.keyPrefix,
    required this.selectedId,
    required this.expectedId,
    required this.checked,
    required this.onSelected,
    super.key,
  });

  final List<Atom> options;
  final String Function(Atom) idFor;
  final String Function(Atom) glyphFor;
  final String Function(Atom) labelFor;
  final String keyPrefix;
  final String? selectedId;
  final String expectedId;
  final bool checked;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, atom) in options.indexed) ...[
        if (index > 0) const Margin.horizontal(12),
        Expanded(
          child: Semantics(
            key: ValueKey('$keyPrefix-${idFor(atom)}'),
            label: labelFor(atom),
            selected: idFor(atom) == selectedId,
            inMutuallyExclusiveGroup: true,
            button: true,
            enabled: !checked,
            onTap: checked ? null : () => onSelected(idFor(atom)),
            child: ExcludeSemantics(
              child: ExerciseChoiceTile(
                glyph: glyphFor(atom),
                index: index,
                selected: idFor(atom) == selectedId,
                accent: checked && idFor(atom) == expectedId
                    ? UIColors.success
                    : checked && idFor(atom) == selectedId
                    ? UIColors.error
                    : null,
                onTap: checked ? null : () => onSelected(idFor(atom)),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
