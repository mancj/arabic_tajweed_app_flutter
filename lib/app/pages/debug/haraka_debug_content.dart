import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';

/// В отладке можно просмотреть все записи, независимо от прогресса курса.
Future<List<Atom>> loadHarakaDebugSyllables() async {
  final curriculum = await const CurriculumLoader().load();
  final syllables = curriculum.nodes.map((node) => node.atom).toList();
  return curriculum.baseLetters
      .expand((letter) => HarakaSyllables.completeFamily(letter, syllables))
      .toList();
}
