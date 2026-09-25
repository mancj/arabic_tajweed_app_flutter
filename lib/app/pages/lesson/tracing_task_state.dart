import 'package:get/get.dart';

import '../../../domain/atom.dart';
import '../../../domain/exercise.dart';
import '../../../domain/progress_event.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../widgets/drawing/tracing_shape_svg.dart';

/// Состояние одного вида задания: рисунок, подсказка и разобранные контуры.
/// Ответ по-прежнему записывает LessonSession через LessonController.
class TracingTaskState {
  TracingTaskState({Future<TracingShape> Function(String asset)? shapeLoader})
    : _shapeLoader = shapeLoader ?? _loadShapeAsset;

  final Future<TracingShape> Function(String asset) _shapeLoader;
  final _shapes = <String, TracingShape>{};

  final drawing = DrawingController();
  final shape = Rxn<TracingShape>();
  final hint = ''.obs;
  final done = false.obs;
  final guideVisible = false.obs;

  Exercise? _exercise;

  static const matcher = TracingMatcher();
  static const _startHint = 'Начните с основы буквы';

  Future<void> preload(List<Exercise> exercises) async {
    final names = exercises
        .where((exercise) => exercise.mode.isTracing)
        .map((exercise) => exercise.atom.tracing)
        .nonNulls
        .toSet();
    for (final name in names) {
      if (_shapes.containsKey(name)) continue;
      try {
        _shapes[name] = await _shapeLoader(name);
      } catch (_) {
        // Отсутствующий контур даёт заглушку только своему заданию.
      }
    }
  }

  void sync(Exercise? exercise) {
    final name = exercise != null && exercise.mode.isTracing
        ? exercise.atom.tracing
        : null;
    drawing.clear();
    _exercise = exercise;
    done.value = false;
    guideVisible.value = false;
    shape.value = name == null ? null : _shapes[name];
    hint.value = shape.value == null ? '' : _startHintFor(exercise);
  }

  bool isAvailableFor(Exercise? exercise) =>
      exercise != null && exercise.mode.isTracing && shape.value != null;

  TracingMode canvasMode(Exercise? exercise, {required bool wasWrong}) =>
      exercise?.mode == ExerciseMode.trace || guideVisible.value || wasWrong
      ? TracingMode.tracing
      : TracingMode.freehand;

  bool isAnchored(Exercise? exercise) =>
      exercise?.atom.kind == AtomKind.haraka ||
      exercise?.mode == ExerciseMode.drawHarakaForSound;

  void clear({required bool wasWrong}) {
    drawing.clear();
    if (wasWrong || guideVisible.value) return;
    done.value = false;
    hint.value = _startHintFor(_exercise);
  }

  void onProgress(TracingProgress progress) {
    final noun = isAnchored(_exercise) ? 'Огласовка' : 'Буква';
    hint.value = progress.isComplete
        ? '$noun готова'
        : 'Нарисуйте: ${progress.nextLabel ?? noun.toLowerCase()}';
  }

  void onMerged() {
    done.value = true;
    hint.value = isAnchored(_exercise) ? 'Огласовка готова' : 'Буква собрана';
  }

  void revealGuide() {
    done.value = false;
    hint.value = 'Обведите по подсказке';
    guideVisible.value = true;
  }

  void giveUp() {
    drawing.clear();
    revealGuide();
  }

  void dispose() => drawing.dispose();

  String _startHintFor(Exercise? exercise) => switch (exercise?.mode) {
    ExerciseMode.drawHarakaForSound => 'Дорисуйте услышанную огласовку',
    ExerciseMode.trace when exercise?.atom.kind == AtomKind.haraka =>
      'Обведите огласовку',
    ExerciseMode.traceFromMemory when exercise?.atom.kind == AtomKind.haraka =>
      'Нарисуйте огласовку по памяти',
    _ => _startHint,
  };

  static Future<TracingShape> _loadShapeAsset(String asset) {
    final path = asset.contains('/')
        ? 'assets/svg/$asset.svg'
        : 'assets/svg/alphabet/$asset.svg';
    return TracingShapeSvg.load(path, id: asset);
  }
}
