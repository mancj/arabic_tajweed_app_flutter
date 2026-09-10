import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/segmented_tabs.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/tracing_card.dart';

import 'tracing_page_controller.dart';

export 'tracing_page_binding.dart';
export 'tracing_page_controller.dart';

/// Экран обводки буквы (макет Tajweed, node 12:293).
///
/// Каркас, полоса прогресса и кнопка «Далее» те же, что на экране знакомства
/// с буквой; отличается только карточка — вместо готового глифа в ней холст,
/// на котором букву обводят по бледной подсказке или рисуют по памяти.
class TracingPage extends GetView<TracingController> {
  static const routeName = '/tracing';

  const TracingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Алфавит',
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: Column(
          children: [
            Obx(() => LessonProgressBar(value: controller.progress)),
            const Margin.vertical(12),
            const _ModeTabs(),
            const Margin.vertical(16),
            const _TracingCard(),
            const Margin.vertical(12),
            const _LetterTabs(),
            const Margin.vertical(8),
            const _FormTabs(),
            const Margin.vertical(12),
            const _CanvasActions(),
          ],
        ),
      ),
    );
  }
}

/// Переключатель режима: обводить бледную букву или рисовать её по памяти.
class _ModeTabs extends GetView<TracingController> {
  const _ModeTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SegmentedTabs(
        labels: TracingController.modeTitles,
        selected: TracingController.modes.indexOf(controller.mode.value),
        onChanged: (index) =>
            controller.setMode(TracingController.modes[index]),
      ),
    );
  }
}

class _LetterTabs extends GetView<TracingController> {
  const _LetterTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LetterTabs(
        glyphs: [for (final item in controller.letters) item.glyph],
        selected: controller.index.value,
        onChanged: controller.setLetter,
      ),
    );
  }
}

/// Форма выбранной буквы. У ا د ذ ر ز و форм две вместо четырёх, поэтому
/// список свой на каждую букву.
class _FormTabs extends GetView<TracingController> {
  const _FormTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final forms = controller.current?.forms ?? const [];
      if (forms.length < 2) return const SizedBox.shrink();

      return SegmentedTabs(
        labels: [for (final form in forms) form.form.title],
        selected: controller.formIndex.value,
        onChanged: controller.setForm,
      );
    });
  }
}

/// Карточка обводки: та же [TracingCard], что и в уроке. В шапке —
/// режим и название формы, показ после промахов идёт по общим правилам.
class _TracingCard extends GetView<TracingController> {
  const _TracingCard();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TracingCard(
        badge: TracingController
            .modeTitles[TracingController.modes.indexOf(controller.mode.value)],
        title: controller.letter?.name ?? '',
        hint: controller.hint.value,
        onClear: controller.clear,
        onPlay: controller.hasVoice ? controller.playVoice : null,
        onAutoPlay: controller.hasVoice ? controller.startVoice : null,
        track: controller.voiceTrack,
        playbackKey: controller.letter?.glyph,
        controller: controller.drawing,
        matcher: TracingController.matcher,
        mode: controller.mode.value,
        shape: controller.shape.value,
        missesBeforeReveal: controller.rules.tracingMissesBeforeReveal,
        onProgress: controller.onProgress,
        onChecked: controller.onChecked,
        onReveal: controller.onRevealed,
      ),
    );
  }
}

/// Отмена и проверка холста; стирание стоит в шапке карточки. Части засчитываются сами, сразу
/// после штриха, — «Проверить» здесь только чтобы увидеть разбор попытки.
class _CanvasActions extends GetView<TracingController> {
  const _CanvasActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconAction(
          icon: Icons.undo_rounded,
          semanticLabel: 'Отменить',
          onTap: controller.undo,
        ),
        const Margin.horizontal(8),
        Expanded(child: _CheckButton(onTap: controller.check)),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Обработчик уходит внутрь [CircleButton]: он сам жестовый детектор,
    // и обёртка снаружи тапа не увидит — внутренний выигрывает арену.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: CircleButton(
        onTap: onTap,
        size: 44,
        child: Icon(icon, size: 20, color: UIColors.highlightArea),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CheckButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: SquircleBorders.squircleBorder(
          color: UIColors.highlightArea,
          borderRadius: 16,
          borderSide: const BorderSide(color: UIColors.borders, width: 0.6),
          shadows: const [
            BoxShadow(
              color: UIColors.borders,
              offset: Offset(0, 3),
              blurRadius: 1.5,
            ),
          ],
        ),
        child: const Text(
          'Проверить',
          style: TextStyle(
            fontFamily: UITextStyles.fontOnest,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: UIColors.secondary2,
          ),
        ),
      ),
    );
  }
}
