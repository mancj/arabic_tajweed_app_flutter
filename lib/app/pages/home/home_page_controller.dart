import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';

/// Буква набора: файл с осевыми линиями, глиф и название для подписей.
class LessonLetter {
  /// Имя SVG в `assets/svg/alphabet` — оно же id фигуры.
  final String id;
  final String glyph;
  final String name;

  const LessonLetter({
    required this.id,
    required this.glyph,
    required this.name,
  });
}

class HomeController extends GetxController {
  final drawing = DrawingController(smoothing: .4, minDistance: 8);

  /// Буквы лежат в assets как SVG с осевыми линиями.
  static const letters = [
    LessonLetter(id: 'ba_base', glyph: 'ب', name: 'Ба'),
    LessonLetter(id: 'ta_base', glyph: 'ت', name: 'Та'),
    LessonLetter(id: 'sin_base', glyph: 'س', name: 'Син'),
    LessonLetter(id: 'shin_base', glyph: 'ش', name: 'Шин'),
    LessonLetter(id: 'to_base', glyph: 'ط', name: 'То'),
    LessonLetter(id: 'zho_base', glyph: 'ظ', name: 'Зо'),
  ];

  static const modes = [TracingMode.tracing, TracingMode.freehand];
  static const modeTitles = ['Обводка', 'По памяти'];

  /// Один и тот же матчер у холста и у подсказок — иначе пороги разъедутся.
  static const matcher = TracingMatcher();

  final index = 0.obs;
  final shape = Rxn<TracingShape>();

  final mode = TracingMode.tracing.obs;

  /// Подсказка над сеткой: что рисовать дальше или что пошло не так.
  final hint = ''.obs;

  LessonLetter get letter => letters[index.value];

  /// Заполнение полосы под шапкой: сколько букв набора пройдено.
  double get progress => (index.value + 1) / letters.length;

  String get nextSubtitle => 'Буква «${letter.name.toLowerCase()}»';

  /// Кнопка «Проверить» нужна только в режиме обводки: по памяти части
  /// засчитываются сами.
  bool get canCheck => mode.value == TracingMode.tracing;

  @override
  void onInit() {
    super.onInit();
    _resetHint();
    _loadLetter();
  }

  Future<void> _loadLetter() async {
    final current = letter;
    shape.value = await TracingShapeSvg.load(
      'assets/svg/alphabet/${current.id}.svg',
      id: current.id,
      label: current.name,
    );
  }

  void setLetter(int value) {
    if (index.value == value) return;
    index.value = value;
    drawing.clear();
    _resetHint();
    _loadLetter();
  }

  void setMode(TracingMode value) {
    if (mode.value == value) return;
    mode.value = value;
    drawing.clear();
    _resetHint();
  }

  void undo() {
    drawing.undo();
    _resetHint();
  }

  void clear() {
    drawing.clear();
    _resetHint();
  }

  /// Следующая буква набора; после последней начинаем сначала.
  void onNext() => setLetter((index.value + 1) % letters.length);

  void check() {
    final result = drawing.check();

    Get.snackbar(
      result.isMatch ? 'Отлично!' : 'Ещё раз',
      _messageFor(result),
      snackPosition: SnackPosition.TOP,
    );
  }

  void onProgress(TracingProgress progress) {
    hint.value = progress.isComplete
        ? 'Буква собрана!'
        : 'Нарисуйте: ${progress.nextLabel ?? '—'}';
  }

  void onChecked(TracingMatchResult result) {
    if (mode.value != TracingMode.freehand || result.isMatch) return;
    hint.value = result.isChecked ? 'Не узнал, попробуйте ещё раз' : hint.value;
  }

  void _resetHint() {
    hint.value = mode.value == TracingMode.tracing
        ? 'Обведите букву'
        : 'Нарисуйте основу буквы';
  }

  String _messageFor(TracingMatchResult result) {
    switch (result.status) {
      case TracingMatchStatus.noInput:
        return 'Сначала обведите букву';
      case TracingMatchStatus.noShape:
        return 'Холст ещё не готов';
      case TracingMatchStatus.checked:
        if (result.isMatch) return 'Буква обведена верно';
        if (!result.dotsTraced && result.coverage > 0.8) {
          return 'Не забудьте точку у буквы';
        }
        if (result.deviation > matcher.maxDeviation) {
          return 'Линия сильно уходит в сторону от буквы';
        }
        return 'Обведено ${(result.coverage * 100).round()}%, '
            'точность ${(result.accuracy * 100).round()}%';
    }
  }

  @override
  void onClose() {
    drawing.dispose();
    super.onClose();
  }
}
