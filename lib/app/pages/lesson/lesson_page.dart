import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_learned_popup.dart';

import 'lesson_controller.dart';
import 'lesson_controls.dart';
import 'lesson_content_view.dart';
import 'lesson_finish_screen.dart';
import 'lesson_notes_page.dart';
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
  bool _notesOpen = false;

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
      try {
        final advance = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: UIColors.transparent,
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          builder: (_) => LessonResultSheet(controller: controller),
        );
        if (!mounted || advance != true) return;
        await _showLearnedPopups();
        if (mounted) await controller.submit();
      } finally {
        _sheetOpen = false;
      }
    });
  }

  Future<void> _showNotes() async {
    if (_notesOpen || _sheetOpen) return;
    _notesOpen = true;
    try {
      controller.markLessonNotesSeen();
      await Get.to<void>(
        () => LessonNotesPage(controller: controller),
        routeName: LessonNotesPage.routeName,
      );
    } finally {
      _notesOpen = false;
    }
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
        actions: [
          Obx(() {
            final stage = controller.stage.value;
            return stage == LessonStage.intro || stage == LessonStage.exercise
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppScaffoldActionButton(
                        icon: SvgPicture.asset(
                          UISVGAssets.notes,
                          colorFilter: ColorFilter.mode(
                            UIColors.text,
                            BlendMode.srcIn,
                          ),
                        ),
                        onPressed: _showNotes,
                        semanticLabel: 'Конспект занятия',
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Semantics(
                          container: true,
                          label: controller.unreadLessonNotes.value == 0
                              ? null
                              : 'Новых конспектов: ${controller.unreadLessonNotes.value}',
                          child: IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: controller.unreadLessonNotes.value == 0
                                  ? const SizedBox.shrink(key: ValueKey(0))
                                  : ExcludeSemantics(
                                      key: ValueKey(
                                        controller.unreadLessonNotes.value,
                                      ),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: UIColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: UIColors.pageBackground,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${controller.unreadLessonNotes.value}',
                                            style: UITextStyles.monoSemibold11
                                                .copyWith(
                                                  color: UIColors
                                                      .primaryButtonText,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink();
          }),
          Obx(
            () => controller.stage.value == LessonStage.exercise
                ? const LessonDebugMenu()
                : const SizedBox.shrink(),
          ),
        ],
        bottomBar: Obx(() => LessonBottomBar(stage: controller.stage.value)),
        builder: (context, insets) => Obx(() {
          final stage = controller.stage.value;
          return SingleChildScrollView(
            // Каждая новая статья начинается сверху, включая переход
            // от обзора всех форм к объяснению отдельной формы.
            key: ValueKey((
              stage,
              stage == LessonStage.intro
                  ? controller.introAtom?.id
                  : controller.card.value?.id,
              stage == LessonStage.exercise &&
                  controller.formsOverview.isNotEmpty,
            )),
            primary: false,
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
