import 'package:arabic_tajweed_app/app/pages/pronunciation/pronunciation_controller.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/mono_text_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Отдельный стенд задания: запись и проверка настоящие, прогресс не меняется.
/// Ожидание можно показать вручную, даже когда сервер недоступен.
class PronunciationExerciseDebugPage extends StatefulWidget {
  static const routeName = '/debug/pronunciation-exercise';

  const PronunciationExerciseDebugPage({super.key});

  @override
  State<PronunciationExerciseDebugPage> createState() =>
      _PronunciationExerciseDebugPageState();
}

class _PronunciationExerciseDebugPageState
    extends State<PronunciationExerciseDebugPage> {
  final controller = Get.find<PronunciationController>();
  bool previewChecking = false;

  @override
  Widget build(BuildContext context) {
    final checker = controller.checker;

    return AppScaffold(
      title: 'Тест произношения',
      bottomBar: Obx(() {
        final state = switch ((
          checker.isRecording.value,
          previewChecking || checker.isChecking.value,
        )) {
          (_, true) => PronunciationRecorderState.checking,
          (true, false) => PronunciationRecorderState.recording,
          _ => PronunciationRecorderState.idle,
        };
        return PronunciationRecorderWidget(
          state: state,
          level: checker.level,
          onRecordPressed: controller.atom == null
              ? null
              : () {
                  checker.reset();
                  controller.startRecording();
                },
          onStopPressed: controller.stopRecording,
          microphonePermissionDenied:
              checker.failure.value ==
              PronunciationFailureKind.microphoneDenied,
          microphoneSettingsRequired: checker.microphoneSettingsRequired.value,
          onOpenSettings: checker.openMicrophoneSettings,
        );
      }),
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => LessonProgressBar(value: controller.progress, wavy: true),
            ),
            const Margin.vertical(16),
            Obx(() {
              final atom = controller.atom;
              if (atom == null) return const SizedBox.shrink();
              return LetterWidgetCard(
                key: ValueKey(atom.id),
                letter: atom.display,
                isArabic: true,
                labelText: 'Вопрос',
                question: 'Назовите эту букву вслух',
                showPlay: false,
              );
            }),
            const Margin.vertical(24),
            Text(
              'ВЫБЕРИТЕ БУКВУ',
              style: UITextStyles.monoSemibold11.copyWith(
                color: UIColors.secondary2,
              ),
            ),
            const Margin.vertical(8),
            Obx(
              () => LetterTabs(
                glyphs: [for (final atom in controller.letters) atom.display],
                selected: controller.index.value,
                onChanged: (index) {
                  if (previewChecking ||
                      checker.isRecording.value ||
                      checker.isChecking.value) {
                    return;
                  }
                  controller.setLetter(index);
                },
              ),
            ),
            const Margin.vertical(8),
            Obx(
              () => MonoTextButton(
                title: previewChecking
                    ? 'Завершить ожидание'
                    : 'Показать ожидание без сервера',
                icon: previewChecking
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline_rounded,
                onPressed: checker.isRecording.value || checker.isChecking.value
                    ? null
                    : () => setState(() {
                        if (!previewChecking) checker.reset();
                        previewChecking = !previewChecking;
                      }),
              ),
            ),
            const Margin.vertical(16),
            Obx(() {
              if (previewChecking || checker.isChecking.value) {
                return const SizedBox.shrink();
              }
              if (checker.failure.value ==
                  PronunciationFailureKind.microphoneDenied) {
                return const SizedBox.shrink();
              }
              if (checker.error.value case final error?) {
                return RuleCard(badge: 'Не вышло', title: error);
              }
              final result = checker.result.value;
              if (result == null) return const SizedBox.shrink();
              return RuleCard(
                badge: result.matched ? 'Верно' : 'Не то',
                title: 'Услышано: ${result.heard} — ${result.hint}',
              );
            }),
          ],
        ),
      ),
    );
  }
}
