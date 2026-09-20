import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_learned_popup.dart';

import 'lesson_controller.dart';
import 'lesson_controls.dart';
import 'lesson_content_view.dart';
import 'lesson_finish_screen.dart';
import 'lesson_result_sheet.dart';

export 'lesson_binding.dart';
export 'lesson_controller.dart';

/// Экран урока: одна сцена, которая переключает режимы упражнений.
///
/// Блок «новое» показывает атом без проверки, дальше идёт очередь заданий.
/// Ошибка не выкидывает из урока — верный ответ подсвечивается, задание
/// возвращается в конец очереди. См. SPEC.md §5.
class LessonPage extends GetView<LessonController> {
  static const routeName = '/lesson';

  const LessonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ResultSheetHost(controller: controller);
  }
}

class _ResultSheetHost extends StatefulWidget {
  const _ResultSheetHost({required this.controller});

  final LessonController controller;

  @override
  State<_ResultSheetHost> createState() => _ResultSheetHostState();
}

class _ResultSheetHostState extends State<_ResultSheetHost> {
  late final Worker _correctWorker;
  late final Worker _wrongWorker;
  bool _sheetOpen = false;
  bool _popupOpen = false;

  LessonController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _correctWorker = ever(controller.wasCorrect, (_) => _showResultSheet());
    _wrongWorker = ever(controller.wasWrong, (_) => _showResultSheet());
  }

  void _showResultSheet() {
    if (!mounted || _sheetOpen) return;
    if (controller.isDebugFinishingLesson) return;
    if (!controller.wasCorrect.value && !controller.wasWrong.value) return;

    _sheetOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          controller.isDebugFinishingLesson ||
          (!controller.wasCorrect.value && !controller.wasWrong.value)) {
        _sheetOpen = false;
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: UIColors.transparent,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (_) => LessonResultSheet(controller: controller),
      );
      _sheetOpen = false;
      await _showLearnedPopups();
    });
  }

  Future<void> _showLearnedPopups() async {
    if (!mounted || _popupOpen) return;
    _popupOpen = true;
    try {
      while (mounted && controller.learnedLetters.isNotEmpty) {
        final atom = controller.learnedLetters.removeAt(0);
        await showLetterLearnedPopup(context, atom: atom);
      }
    } finally {
      _popupOpen = false;
    }
  }

  @override
  void dispose() {
    _correctWorker.dispose();
    _wrongWorker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.stage.value == LessonStage.finished) {
        return LessonFinishScreen(controller: controller);
      }
      return AppScaffold(
        title: controller.isReviewOnly ? 'Повторение' : 'Урок',
        actions: kDebugMode
            ? [
                Obx(
                  () => controller.stage.value == LessonStage.exercise
                      ? const LessonDebugMenu()
                      : const SizedBox.shrink(),
                ),
              ]
            : const [],
        bottomBar: Obx(() => LessonBottomBar(stage: controller.stage.value)),
        builder: (context, insets) => Obx(() {
          final stage = controller.stage.value;
          return SingleChildScrollView(
            // Холст обрабатывает жесты рисования внутри себя. Страница
            // остаётся прокручиваемой, чтобы дойти до кнопок под карточкой.
            padding: insets,
            child: switch (stage) {
              LessonStage.loading => const LessonLoadingView(),
              LessonStage.intro => const LessonIntroBlock(),
              LessonStage.exercise => const LessonExerciseBlock(),
              LessonStage.finished => const SizedBox.shrink(),
            },
          );
        }),
      );
    });
  }
}
