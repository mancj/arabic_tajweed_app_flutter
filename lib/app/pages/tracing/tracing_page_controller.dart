import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_shape_svg.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/data/letter_audio.dart';
import 'package:arabic_tajweed_app/domain/audio_track.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/learning_rules.dart';

/// Форма буквы на отладочном экране: файл с осевыми линиями, глиф
/// и название для подписей.
class LessonLetter {
  /// Имя SVG в `assets/svg/alphabet` — оно же id фигуры.
  final String id;
  final String glyph;
  final String name;
  final LetterForm form;

  const LessonLetter({
    required this.id,
    required this.glyph,
    required this.name,
    required this.form,
  });
}

/// Буква со всеми формами, у которых есть осевой SVG.
class LessonLetterForms {
  final String letterId;
  final List<LessonLetter> forms;

  const LessonLetterForms({required this.letterId, required this.forms});

  /// Чем буква подписана в полосе выбора: изолированный глиф, а если его
  /// нет — глиф первой доступной формы.
  String get glyph => forms.first.glyph;
}

class TracingController extends GetxController {
  final drawing = DrawingController();
  final _audio = LetterAudio();

  bool get hasVoice => LetterAudio.has(current?.letterId);
  ValueListenable<AudioTrack> get voiceTrack => _audio.track;
  void playVoice() => unawaited(_audio.toggle(current?.letterId));
  void startVoice() => unawaited(_audio.play(current?.letterId));

  /// Правила те же, что в уроке: показ после промахов срабатывает
  /// на том же счёте.
  final rules = const LearningRules();

  /// Набор берётся из курикулума, а не из своего списка: так на отладочном
  /// экране всегда ровно те же буквы и формы, что урок умеет спрашивать
  /// обводкой, — включая только что дорисованные.
  final letters = <LessonLetterForms>[].obs;

  static const modes = [TracingMode.tracing, TracingMode.freehand];
  static const modeTitles = ['Обводка', 'По памяти'];

  /// Один и тот же матчер у холста и у подсказок — иначе пороги разъедутся.
  static const matcher = TracingMatcher();

  final index = 0.obs;
  final formIndex = 0.obs;
  final shape = Rxn<TracingShape>();

  final mode = TracingMode.tracing.obs;

  /// Подсказка над сеткой: что рисовать дальше или что пошло не так.
  final hint = ''.obs;

  LessonLetterForms? get current =>
      letters.isEmpty ? null : letters[index.value];

  LessonLetter? get letter {
    final forms = current?.forms;
    if (forms == null || forms.isEmpty) return null;
    return forms[formIndex.value.clamp(0, forms.length - 1)];
  }

  /// Заполнение полосы под шапкой: сколько букв набора пройдено.
  double get progress =>
      letters.isEmpty ? 0 : (index.value + 1) / letters.length;

  Future<void>? _ready;

  /// Набор и текущая фигура загружены. Ассеты читаются в две очереди —
  /// сперва курикулум, потом SVG, — и тесту нужно на что-то дождаться,
  /// прежде чем щупать холст. Смена буквы обновляет это обещание.
  Future<void> get ready => _ready ?? Future.value();

  @override
  void onInit() {
    super.onInit();
    _resetHint();
    _ready = _loadLetters();
  }

  Future<void> _loadLetters() async {
    final curriculum = await const CurriculumLoader().load();
    final tracing = curriculum.nodes
        .map((node) => node.atom)
        .where((atom) => atom.kind == AtomKind.letterForm)
        .where((atom) => atom.tracing != null && atom.letterId != null);

    letters.value = [
      for (final entry in groupBy(tracing, (atom) => atom.letterId!).entries)
        LessonLetterForms(
          letterId: entry.key,
          forms: [
            for (final atom in entry.value.sortedBy<num>(
              (atom) => LetterForm.values.indexOf(atom.form!),
            ))
              LessonLetter(
                id: atom.tracing!,
                glyph: atom.display,
                name: atom.label,
                form: atom.form!,
              ),
          ],
        ),
    ];
    await _loadShape();
  }

  Future<void> _loadShape() async {
    final current = letter;
    if (current == null) return;
    shape.value = await TracingShapeSvg.load(
      'assets/svg/alphabet/${current.id}.svg',
      id: current.id,
      label: current.name,
    );
  }

  void setLetter(int value) {
    if (index.value == value) return;
    unawaited(_audio.stop());
    index.value = value;
    // Форма сбрасывается на изолированную: у несоединяющихся букв средней
    // формы нет, и прежний индекс уехал бы за конец списка.
    formIndex.value = 0;
    _restart();
  }

  void setForm(int value) {
    if (formIndex.value == value) return;
    formIndex.value = value;
    _restart();
  }

  void _restart() {
    drawing.clear();
    _resetHint();
    _ready = _loadShape();
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
    if (result.isMatch) return;
    hint.value = result.isChecked ? 'Не узнал, попробуйте ещё раз' : hint.value;
  }

  /// Холст сам показал, как пишется, после серии промахов: контур открыт,
  /// показ идёт. Экрану остаётся сменить подсказку.
  void onRevealed() {
    hint.value = 'Смотрите, как пишется, и попробуйте ещё раз';
  }

  void _resetHint() => hint.value = 'Нарисуйте основу буквы';

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
    unawaited(_audio.dispose());
    super.onClose();
  }
}
