import 'package:arabic_tajweed_app/data/rest/pronunciation_check.dart';

import 'reading_pronunciation_debug_page.dart';

class SyllablePronunciationDebugPage extends ReadingPronunciationDebugPage {
  static const routeName = '/debug/syllable-pronunciation';

  const SyllablePronunciationDebugPage({
    super.checker,
    super.audio,
    super.syllables,
    super.key,
  }) : super(title: 'Чтение слога вслух', type: PronunciationUnitType.syllable);
}
