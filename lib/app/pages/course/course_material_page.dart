import 'package:flutter/material.dart';

import '../../../domain/atom.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/ui_kit/explanation_asset_card.dart';
import '../../widgets/ui_kit/notes_pager.dart';
import '../../widgets/ui_kit/rule_card.dart';

class CourseMaterialPage extends StatelessWidget {
  const CourseMaterialPage({
    required this.atoms,
    required this.initialIndex,
    super.key,
  });

  final List<Atom> atoms;
  final int initialIndex;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Материал блока',
    builder: (context, insets) => NotesPager(
      items: [
        for (final atom in atoms)
          (id: atom.id, title: atom.label.isEmpty ? atom.display : atom.label),
      ],
      insets: insets,
      initialIndex: initialIndex,
      tabKeyPrefix: 'topic-note',
      itemBuilder: (context, index, active) {
        final atom = atoms[index];
        return atom.explanationAsset != null
            ? ExplanationAssetCard(
                asset: atom.explanationAsset!,
                active: active,
              )
            : RuleCard(
                title: atom.label.isEmpty ? atom.display : atom.label,
                text: atom.note,
              );
      },
    ),
  );
}
