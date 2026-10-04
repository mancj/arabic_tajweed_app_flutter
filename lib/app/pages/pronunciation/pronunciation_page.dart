import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/pronunciation_recorder_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/data/rest/letter_check.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'pronunciation_controller.dart';

export 'pronunciation_binding.dart';
export 'pronunciation_controller.dart';

/// Экран тренировки произношения: как экран обводки, только с голосом.
/// Карточка буквы с эталонным звучанием, полоса выбора буквы, под ними
/// ответ сервера целиком — с оценкой и ближайшими кандидатами, чтобы
/// видеть, как модель слышит каждую букву.
class PronunciationPage extends GetView<PronunciationController> {
  static const routeName = '/pronunciation';

  const PronunciationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Произношение',
      bottomBar: Obx(() {
        final checker = controller.checker;
        final state = switch ((
          checker.isRecording.value,
          checker.isChecking.value,
        )) {
          (_, true) => PronunciationRecorderState.checking,
          (true, false) => PronunciationRecorderState.recording,
          _ => PronunciationRecorderState.idle,
        };
        return PronunciationRecorderWidget(
          state: state,
          level: checker.level,
          onRecordPressed: controller.startRecording,
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
            const _LetterCard(),
            const Margin.vertical(12),
            const _Letters(),
            const Margin.vertical(16),
            const _Feedback(),
          ],
        ),
      ),
    );
  }
}

class _LetterCard extends GetView<PronunciationController> {
  const _LetterCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final atom = controller.atom;
      if (atom == null) return const SizedBox.shrink();
      // Здесь звучание не подсказка, а эталон: сначала послушать, потом
      // повторить. Ключ по букве, чтобы карточка пересоздавалась вместе
      // с ней, а не тянула волну прошлой.
      return LetterWidgetCard(
        key: ValueKey(atom.id),
        letter: atom.display,
        isArabic: true,
        labelText: 'Буква',
        question: 'Назовите букву вслух',
        subtitle: atom.label,
        autoPlay: false,
        onPlay: controller.hasVoice ? controller.playVoice : null,
        track: controller.voiceTrack,
      );
    });
  }
}

class _Letters extends GetView<PronunciationController> {
  const _Letters();

  @override
  Widget build(BuildContext context) => Obx(
    () => LetterTabs(
      glyphs: [for (final atom in controller.letters) atom.display],
      selected: controller.index.value,
      onChanged: controller.setLetter,
    ),
  );
}

/// Ответ сервера целиком. Пока записи не было — пусто.
class _Feedback extends GetView<PronunciationController> {
  const _Feedback();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final checker = controller.checker;
      if (checker.failure.value == PronunciationFailureKind.microphoneDenied) {
        return const SizedBox.shrink();
      }
      if (checker.error.value case final error?) {
        return RuleCard(badge: 'Не вышло', title: error);
      }
      final check = checker.result.value;
      if (check == null) return const SizedBox.shrink();

      return RuleCard(
        badge: check.matched ? 'Верно' : 'Не то',
        title: 'Услышано: ${check.heard} — ${check.hint}',
        text: _details(check),
      );
    });
  }

  String _details(LetterCheck check) {
    final nearest = check.nearest
        .map((g) => '${g.letter} ${(g.similarity * 100).round()}%')
        .join(', ');
    final rec = check.recording;
    return [
      'Оценка ${check.score} из 100. Похожие: $nearest.',
      'Запись: речь с ${rec.speechFrom} с, громкость ${rec.loudnessDb} дБ, '
          'чистота ${rec.clarityDb} дБ'
          '${rec.warning == null ? '' : ', ${rec.warning}'}.',
    ].join('\n');
  }
}
