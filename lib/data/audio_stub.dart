import 'package:flutter/foundation.dart';

import '../domain/atom.dart';

/// ЗАГЛУШКА. Аудио ещё нет: 28 имён букв, 28 звуков, 84 слога и набор
/// озвученных сочетаний предстоит сгенерировать через TTS. См. SPEC.md §12.
///
/// Пока сервис только сообщает, чего не хватает, и молчит. Когда файлы
/// появятся, здесь останется подменить реализацию на настоящий плеер —
/// вызывающий код менять не придётся.
///
/// TODO(audio): положить файлы в assets/audio/{letters,sounds,syllables},
/// подключить плеер, включить режимы soundToLetter и letterToSound.
class AudioStub {
  const AudioStub();

  /// Путь, по которому будет лежать озвучка имени буквы.
  String nameAssetOf(Atom atom) => 'assets/audio/letters/${atom.letterId}.opus';

  /// Путь к звуку буквы — тому, как она читается, а не как называется.
  String soundAssetOf(Atom atom) => 'assets/audio/sounds/${atom.letterId}.opus';

  bool get isReady => false;

  Future<void> play(String asset) async {
    debugPrint('AudioStub: нет файла $asset — озвучка ещё не записана');
  }
}
