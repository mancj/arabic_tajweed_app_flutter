import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/connected_word_content.dart';
import 'package:arabic_tajweed_app/domain/connection_build_question.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/word_build_question.dart';

/// Подборки общего банка для просмотра. Отладка не добавляет материал в курс.
Future<List<ConnectionBuildQuestion>>
loadConnectionBuildDebugQuestions() async {
  final content = await _loadContent(['harakaIntroduction', 'wordBuildDebug']);
  final words = content.availableWords;
  return [
    // Сначала конец и начало; средняя форма появляется на трёх буквах.
    for (final word in words)
      content.connection(word, missingIndex: word.steps.length - 1),
    for (final word in words) content.connection(word, missingIndex: 0),
    for (final word in words)
      for (var index = 1; index < word.steps.length - 1; index++)
        content.connection(word, missingIndex: index),
  ];
}

Future<List<WordBuildQuestion>> loadWordBuildDebugQuestions() async {
  final content = await _loadContent(['wordBuildDebug']);
  return content.availableWords;
}

Future<ConnectedWordContent> _loadContent(List<String> sets) async {
  final curriculum = await const CurriculumLoader().load();
  final introduced = curriculum.nodes.map((node) => node.atom).toList();
  final syllables = {
    for (final letter in curriculum.baseLetters)
      for (final syllable in HarakaSyllables.completeFamily(letter, introduced))
        syllable.id: syllable,
  };
  final words = {
    for (final set in sets)
      for (final word in curriculum.wordsForSet(set)) word.id: word,
  };
  return ConnectedWordContent([
    ...introduced,
    ...syllables.values,
  ], words: words.values.toList());
}
