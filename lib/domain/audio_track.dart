/// Состояние звучащей записи: её форма и то, сколько уже проиграно.
///
/// Живёт в домене, потому что нужен по обе стороны: плеер его наполняет,
/// а виджет волны — рисует. Ни один из них не должен знать про другой.
class AudioTrack {
  /// Пики записи, 0..1, слева направо. Пусто — форму снять не удалось
  /// (извлечение есть только на Android и iOS), волна тогда живёт сама.
  final List<double> levels;

  /// Доля проигранного, 0..1.
  final double progress;

  final bool isPlaying;

  const AudioTrack({
    this.levels = const [],
    this.progress = 0,
    this.isPlaying = false,
  });

  static const silent = AudioTrack();

  /// Громкость в текущей точке воспроизведения — то, подо что волна дышит.
  /// Нет пиков — нет и уровня.
  double get level {
    if (levels.isEmpty) return 0;
    final i = (progress * levels.length).floor().clamp(0, levels.length - 1);
    return levels[i];
  }

  AudioTrack copyWith({
    List<double>? levels,
    double? progress,
    bool? isPlaying,
  }) => AudioTrack(
    levels: levels ?? this.levels,
    progress: progress ?? this.progress,
    isPlaying: isPlaying ?? this.isPlaying,
  );
}
