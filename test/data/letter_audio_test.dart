import 'dart:io';

import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Плеер глотает ошибки, поэтому отсутствующий файл в приложении выглядит
  // как «буква не звучит». Ловим расхождение имён здесь, а не руками.
  test('every voiced letter has a recording in assets', () {
    final missing = LetterAudio.letters
        .where((id) => !File('assets/${LetterAudio.assetOf(id)}').existsSync())
        .toList();
    expect(missing, isEmpty);
  });

  test('every recording belongs to a voiced letter', () {
    final orphans = Directory('assets/audio/alphabet')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.wav'))
        .map((name) => name.replaceAll('.wav', ''))
        .where((id) => !LetterAudio.has(id))
        .toList();
    expect(orphans, isEmpty);
  });
}
