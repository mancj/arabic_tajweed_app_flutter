import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';
import 'package:arabic_tajweed_app/domain/letter_learning.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:flutter_test/flutter_test.dart';

// Защищает награду от преждевременного показа после одной формы или без
// обязательной практики, а также от зачёта по облегчённому критерию.
void main() {
  const base = Atom(
    id: 'alif.isolated',
    kind: AtomKind.letterForm,
    display: 'ا',
    label: 'Алиф',
    letterId: 'alif',
    form: LetterForm.isolated,
    tracing: 'alif_base',
  );
  const finalForm = Atom(
    id: 'alif.final',
    kind: AtomKind.letterForm,
    display: 'ـا',
    letterId: 'alif',
    form: LetterForm.finalForm,
  );
  const curriculum = Curriculum(
    nodes: [
      CurriculumNode(atom: base, requirement: Always()),
      CurriculumNode(atom: finalForm, requirement: Always()),
    ],
    topics: [],
  );
  const learning = LetterLearning(
    curriculum,
    LearningRules(requirePronunciation: false),
  );
  const baseProgress = AtomProgress(
    state: AtomState.known,
    successfulModes: {ExerciseMode.trace, ExerciseMode.traceFromMemory},
  );

  test('буква ждёт все формы, включая конечную', () {
    expect(learning.isLearned('alif', {base.id: baseProgress}), isFalse);
    expect(
      learning.isLearned('alif', {
        base.id: baseProgress,
        finalForm.id: const AtomProgress(state: AtomState.learning),
      }),
      isFalse,
    );
    expect(
      learning.isLearned('alif', {
        base.id: baseProgress,
        finalForm.id: const AtomProgress(state: AtomState.known),
      }),
      isTrue,
    );
  });

  test('известные формы без письма или с weak не дают награду', () {
    expect(
      learning.isLearned('alif', {
        base.id: const AtomProgress(state: AtomState.known),
        finalForm.id: const AtomProgress(state: AtomState.known),
      }),
      isFalse,
    );
    expect(
      learning.isLearned('alif', {
        base.id: baseProgress,
        finalForm.id: const AtomProgress(state: AtomState.known, weak: true),
      }),
      isFalse,
    );
  });

  test('для соединяющейся буквы нужны все четыре формы', () {
    const forms = [
      Atom(
        id: 'ba.isolated',
        kind: AtomKind.letterForm,
        display: 'ب',
        letterId: 'ba',
        form: LetterForm.isolated,
      ),
      Atom(
        id: 'ba.initial',
        kind: AtomKind.letterForm,
        display: 'بـ',
        letterId: 'ba',
        form: LetterForm.initial,
      ),
      Atom(
        id: 'ba.medial',
        kind: AtomKind.letterForm,
        display: 'ـبـ',
        letterId: 'ba',
        form: LetterForm.medial,
      ),
      Atom(
        id: 'ba.final',
        kind: AtomKind.letterForm,
        display: 'ـب',
        letterId: 'ba',
        form: LetterForm.finalForm,
      ),
    ];
    final fourFormCurriculum = Curriculum(
      nodes: [
        for (final atom in forms)
          CurriculumNode(atom: atom, requirement: const Always()),
      ],
      topics: [],
    );
    final fourFormLearning = LetterLearning(
      fourFormCurriculum,
      const LearningRules(requirePronunciation: false),
    );
    final progress = {
      for (final atom in forms)
        atom.id: const AtomProgress(state: AtomState.known),
    };
    progress.remove(forms.last.id);
    expect(fourFormLearning.isLearned('ba', progress), isFalse);
    progress[forms.last.id] = const AtomProgress(state: AtomState.known);
    expect(fourFormLearning.isLearned('ba', progress), isTrue);
  });
}
