import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';

import 'lesson_controller.dart';
import 'lesson_exercise_presentation.dart';

class LessonBottomBar extends GetView<LessonController> {
  const LessonBottomBar({required this.stage, super.key});

  final LessonStage stage;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      LessonStage.loading => const SizedBox.shrink(),
      LessonStage.intro => NextButton(
        title: 'Понятно',
        onTap: controller.nextIntro,
      ),
      LessonStage.exercise => Obx(() {
        if (controller.wasWrong.value) {
          return const SizedBox.shrink();
        }

        // Карточка формы перекрывает задание: сначала объяснение,
        // потом вопрос про ту же букву.
        if (controller.card.value != null) {
          return NextButton(title: 'Понятно', onTap: controller.dismissCard);
        }

        final exercise = controller.current;
        final input = exercise == null
            ? null
            : LessonExercisePresentation.from(exercise).input;
        final isTracing = controller.isTracingTask;
        final isSayName = input == LessonInputKind.pronunciation;
        final isFormSequence = input == LessonInputKind.formSequence;

        // У заглушки нет своей проверки — обе ветки задаёт человек.
        // TODO(stub): убрать вторую кнопку вместе с заглушками.
        final isStub =
            exercise != null && !exercise.isChoice && !isTracing && !isSayName;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (isTracing)
              _TracingBar(mode: exercise!.mode)
            else if (isSayName)
              const _PronunciationRecorderBar()
            else if (isFormSequence)
              const SizedBox.shrink()
            else if (isStub)
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: NextButton(
                      title: 'Ответить',
                      onTap: () => controller.submitStub(correct: true),
                    ),
                  ),
                  const Margin.horizontal(8),
                  Expanded(
                    child: NextButton(
                      title: 'Ошибиться',
                      onTap: () => controller.submitStub(correct: false),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: NextButton(
                  title: controller.wasWrong.value ? 'Ясно' : 'Ответить',
                  enabled: controller.canSubmit,
                  onTap: controller.canSubmit
                      ? () => controller.submit()
                      : null,
                ),
              ),
          ],
        );
      }),
      LessonStage.finished => const SizedBox.shrink(),
    };
  }
}

class LessonDebugMenu extends GetView<LessonController> {
  const LessonDebugMenu({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final canActOnCurrent =
        controller.card.value == null &&
        !controller.wasCorrect.value &&
        !controller.wasWrong.value &&
        controller.current != null;
    final availableWidth = MediaQuery.sizeOf(context).width - 32;
    final menuWidth = availableWidth < 320 ? availableWidth : 320.0;
    final itemStyle = UITextStyles.regular15;

    return GlassMenu(
      menuAlignment: GlassMenuAlignment.topRight,
      autoAdjustToScreen: true,
      menuPadding: const EdgeInsets.all(0),
      menuWidth: menuWidth,
      menuBorderRadius: 24,
      itemBorderRadius: 16,
      quality: AppScaffoldActionButton.defaultQuality,
      settings: AppScaffoldActionButton.menuSettings,
      items: [
        GlassMenuItem(
          title: 'Ответить верно',
          icon: const Icon(Icons.check_circle_outline_rounded),
          titleStyle: itemStyle,
          enabled: canActOnCurrent,
          onTap: controller.answerCorrectly,
        ),
        GlassMenuItem(
          title: 'Пропустить',
          icon: const Icon(Icons.skip_next_outlined),
          titleStyle: itemStyle,
          enabled: canActOnCurrent,
          onTap: controller.skipExercise,
        ),
        const GlassMenuDivider(),
        GlassMenuItem(
          title: 'Завершить урок с правильными ответами',
          icon: const Icon(Icons.done_all_rounded),
          titleStyle: itemStyle,
          height: 64,
          maxLines: 2,
          onTap: controller.finishLessonCorrectly,
        ),
      ],
      triggerBuilder: (context, toggleMenu) => AppScaffoldActionButton(
        icon: Icon(Icons.bug_report_outlined, color: UIColors.text),
        semanticLabel: 'Меню отладки урока',
        onPressed: toggleMenu,
      ),
    );
  });
}

/// Нижняя панель заданий на письмо.
///
/// После последней части результат открывается сразу в обоих режимах.
/// В письме по памяти остаётся только выход для того, кто букву не вспомнил.
class _TracingBar extends GetView<LessonController> {
  const _TracingBar({required this.mode});

  final ExerciseMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == ExerciseMode.trace) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      if (controller.tracingGuideVisible.value) {
        return const SizedBox.shrink();
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.giveUpTracing,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(
                'Не помню, показать',
                style: UITextStyles.regular12.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Нижняя панель задания «назови букву». Если сервера нет, под кнопкой
/// выход из задания.
class _PronunciationRecorderBar extends GetView<LessonController> {
  const _PronunciationRecorderBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final checker = controller.pronunciation;
      final state = switch ((
        checker.isRecording.value,
        checker.isChecking.value,
      )) {
        (_, true) => PronunciationRecorderState.checking,
        (true, false) => PronunciationRecorderState.recording,
        _ => PronunciationRecorderState.idle,
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PronunciationRecorderWidget(
            state: state,
            level: checker.level,
            onRecordPressed: controller.startRecording,
            onStopPressed: controller.stopRecording,
          ),
          Visibility(
            visible: checker.error.value != null,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.skipExercise,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Продолжить без произношения',
                  style: UITextStyles.monoMedium12.copyWith(
                    color: UIColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Отклик сервера под карточкой буквы: что он услышал и что делать
/// дальше. Пока записи не было — пусто, карточка вопроса говорит сама.
