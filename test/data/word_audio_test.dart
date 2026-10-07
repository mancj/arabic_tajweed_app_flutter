// Готовые записи не должны потеряться из ассетов или вернуться на TTS
// после правки банка, подборки либо карточки объяснения. Проверяем файлы
// через настоящий bundle: наличие MP3 на диске не гарантирует его упаковку.
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/explanation_loader.dart';
import 'package:arabic_tajweed_app/domain/explanation_document.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('слова действующих подборок используют упакованные записи', () async {
    final curriculum = await const CurriculumLoader().load();
    for (final set in ['harakaIntroduction', 'wordReading', 'wordBuildDebug']) {
      final words = curriculum.wordsForSet(set);
      expect(words, isNotEmpty, reason: set);
      for (final word in words) {
        expect(word.recorded, isTrue, reason: word.id);
        expect(word.audioAsset, word.audioFile, reason: word.id);
      }
    }
    for (final word in curriculum.words.where((word) => word.recorded)) {
      final asset = await rootBundle.load('assets/${word.audioFile}');
      expect(asset.lengthInBytes, greaterThan(3), reason: word.id);
      final bytes = asset.buffer.asUint8List(asset.offsetInBytes, 3);
      final isMp3 =
          (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
          (bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0);
      expect(isMp3, isTrue, reason: word.id);
    }
  });

  test('карточки первых слов проигрывают ту же запись, что задания', () async {
    final curriculum = await const CurriculumLoader().load();
    for (final word in curriculum.wordsForSet('wordReading')) {
      final atom = curriculum.nodes
          .singleWhere((node) => node.atom.wordId == word.id)
          .atom;
      final card = ExplanationLoader.parse(
        await rootBundle.loadString(atom.explanationAsset!),
        sourceName: atom.explanationAsset!,
      );
      final glyph = card.document.blocks
          .whereType<ExplanationLetter>()
          .single
          .letter;
      expect(glyph.glyph, word.display);
      expect(glyph.audio, word.audioFile, reason: word.id);
      expect(atom.audioAsset, word.audioFile, reason: word.id);
    }
  });
}
