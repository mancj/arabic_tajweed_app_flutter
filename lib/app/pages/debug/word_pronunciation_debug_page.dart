import 'package:arabic_tajweed_app/data/rest/pronunciation_check.dart';

import 'reading_pronunciation_debug_page.dart';

class WordPronunciationDebugPage extends ReadingPronunciationDebugPage {
  static const routeName = '/debug/word-pronunciation';

  const WordPronunciationDebugPage({
    super.checker,
    super.audio,
    super.words,
    super.key,
  }) : super(title: 'Чтение слова вслух', type: PronunciationUnitType.word);
}
