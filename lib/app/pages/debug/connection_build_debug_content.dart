import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';

/// Лёгкие соединения без новых знаков и разрывов. Это примеры для просмотра,
/// они не добавляют атомы или обязательные темы в программу курса.
Future<List<ConnectionBuildQuestion>>
loadConnectionBuildDebugQuestions() async {
  final curriculum = await const CurriculumLoader().load();
  final introduced = curriculum.nodes.map((node) => node.atom).toList();
  final atoms = {for (final atom in introduced) atom.id: atom};
  final syllables = {
    for (final letter in curriculum.baseLetters)
      for (final syllable in HarakaSyllables.completeFamily(letter, introduced))
        syllable.id: syllable,
  };
  final examples = [
    (['ta.fatha', 'ba.kasra'], 1),
    (['mim.damma', 'ba.fatha'], 1),
    (['nun.kasra', 'mim.damma'], 1),
    (['kaf.fatha', 'ta.fatha'], 0),
    (['kaf.fatha', 'ta.fatha', 'ba.fatha'], 1),
    (['lam.fatha', 'ayn.kasra', 'ba.fatha'], 1),
  ];
  return [
    for (final (syllableIds, missingIndex) in examples)
      ConnectionBuildQuestion(
        missingIndex: missingIndex,
        parts: [
          for (final (index, id) in syllableIds.indexed)
            ConnectionBuildPart(
              syllable: syllables['vowel.$id']!,
              form:
                  atoms['${id.split('.').first}.${index == 0
                      ? 'initial'
                      : index == syllableIds.length - 1
                      ? 'finalForm'
                      : 'medial'}']!,
            ),
        ],
        formOptions: [
          for (final form in [
            LetterForm.medial,
            LetterForm.finalForm,
            LetterForm.initial,
          ])
            atoms['${syllableIds[missingIndex].split('.').first}.${form.name}']!,
        ]..shuffle(),
      ),
  ];
}
