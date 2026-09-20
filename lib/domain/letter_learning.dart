import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'learning_rules.dart';

/// У буквы известны все формы и выполнена обязательная практика.
class LetterLearning {
  const LetterLearning(this.curriculum, this.rules);

  final Curriculum curriculum;
  final LearningRules rules;

  bool isLearned(String letterId, Map<String, AtomProgress> progress) {
    final forms = curriculum.formsByLetter[letterId];
    if (forms == null || forms.isEmpty) return false;
    final base = displayAtom(letterId);
    if (base == null) return false;
    if (!forms.every((id) {
      final p = progress[id];
      return p != null && p.state.index >= AtomState.known.index && !p.weak;
    })) {
      return false;
    }
    return progress[base.id]!.successfulModes.containsAll(
      rules.requiredPracticeModes(base),
    );
  }

  Atom? displayAtom(String letterId) => curriculum.baseLetters.firstWhereOrNull(
    (atom) => atom.letterId == letterId,
  );
}
