// Защищает полный набор записей огласовок: отсутствующий MP3 плеер проглотит
// молча, и упражнение «звук → написание» станет невозможно выполнить.
import 'dart:io';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('у всех 28 букв есть фатха, касра и дамма', () {
    final stage = CurriculumLoader.parse(
      File('assets/curriculum/stage1.json').readAsStringSync(),
    );
    final letterIds = stage.nodes
        .map((node) => node.atom)
        .where((atom) => atom.form == LetterForm.isolated)
        .map((atom) => atom.letterId)
        .whereType<String>()
        .toSet();
    final expected = {
      for (final letterId in letterIds)
        for (final vowel in ['fatha', 'kasra', 'damma'])
          '${letterId}_$vowel.mp3',
    };
    final actual = Directory('assets/audio/harakat')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.mp3'))
        .toSet();

    expect(letterIds, hasLength(28));
    expect(actual, expected);
    expect(
      actual.every(
        (name) => File('assets/audio/harakat/$name').lengthSync() > 0,
      ),
      isTrue,
    );
  });
}
