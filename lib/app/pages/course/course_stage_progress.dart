/// Один счётчик раздела для главной карточки и экранов «Моего пути».
/// В алфавите считаются буквы со всеми формами, дальше — освоенные блоки.
class CourseStageProgress {
  const CourseStageProgress({
    required this.stage,
    required this.done,
    required this.total,
  });

  final int stage;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
  String get unit => stage == 1 ? 'букв освоено' : 'блоков освоено';
  String get summary => stage == 1
      ? 'Освоено букв: $done из $total'
      : 'Освоено блоков: $done из $total';
}
