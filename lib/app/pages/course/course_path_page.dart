// ignore_for_file: prefer_const_constructors

import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../domain/atom.dart';
import '../../../domain/topic_board.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/squircle_borders.dart';
import '../../widgets/ui_kit/badge_label.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/progress_ring.dart';
import 'course_controller.dart';
import 'course_material_page.dart';
import 'knowledge_check_page.dart';

/// Один вид строки для пути, блока материала и перехода с главного.
class CourseLink extends StatelessWidget {
  const CourseLink({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.chevron_right_rounded,
    super.key,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: UIColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SquircleBorders.squircleBorder(
            color: UIColors.cardBackground,
            borderRadius: 20,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: UITextStyles.semibold14),
                    const Margin.vertical(8),
                    Text(
                      subtitle,
                      style: UITextStyles.regular12.copyWith(
                        color: UIColors.secondary2,
                      ),
                    ),
                  ],
                ),
              ),
              const Margin.horizontal(12),
              Icon(icon, color: UIColors.primary),
            ],
          ),
        ),
      ),
    ),
  );
}

class CoursePathPage extends StatelessWidget {
  const CoursePathPage({required this.controller, super.key});
  final CourseController controller;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Мой путь',
    builder: (context, insets) => Obx(() {
      final stages = controller.byStage.entries.toList();
      return ListView(
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          const _PathIntroduction(),
          const Margin.vertical(24),
          for (var index = 0; index < stages.length; index++) ...[
            _CourseStageCard(
              number: index + 1,
              title: CourseController.stageTitle(stages[index].key),
              summary: _summary(stages[index].key, stages[index].value),
              progress: controller.progressForStage(stages[index].key).fraction,
              completed: stages[index].value.every((topic) => topic.isDone),
              available: stages[index].value.any((topic) => topic.canPractice),
              current:
                  !controller.allDone &&
                  stages[index].key == controller.currentStage,
              onTap: () => Get.to(
                () => CourseSectionPage(
                  controller: controller,
                  stage: stages[index].key,
                ),
              ),
            ),
            if (index < stages.length - 1) const Margin.vertical(12),
          ],
        ],
      );
    }),
  );

  String _summary(int stage, List<TopicStatus> topics) {
    final progress = controller.progressForStage(stage);
    if (stage == 1) return progress.summary;
    if (!topics.any((t) => t.canPractice)) {
      return 'Пока закрыто';
    }
    return progress.done == progress.total
        ? 'Освоено · можно повторить'
        : progress.summary;
  }
}

class _PathIntroduction extends StatelessWidget {
  const _PathIntroduction();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПУТЬ ЧТЕНИЯ',
          style: UITextStyles.monoSemibold11.copyWith(
            color: UIColors.studyAccent,
          ),
        ),
        const Margin.vertical(12),
        Text('От букв к словам', style: UITextStyles.semibold29),
      ],
    ),
  );
}

class _CourseStageCard extends StatelessWidget {
  const _CourseStageCard({
    required this.number,
    required this.title,
    required this.summary,
    required this.progress,
    required this.completed,
    required this.available,
    required this.current,
    required this.onTap,
  });

  final int number;
  final String title;
  final String summary;
  final double progress;
  final bool completed;
  final bool available;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !available && !completed;
    final status = completed
        ? 'ОСВОЕНО'
        : locked
        ? 'ВПЕРЕДИ'
        : current
        ? 'СЕЙЧАС'
        : 'ДОСТУПНО';
    return Semantics(
      button: true,
      label:
          '$title. $summary. ${locked ? 'Посмотреть условия открытия' : 'Открыть темы'}',
      child: AppGestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SquircleBorders.squircleBorder(
            color: current ? UIColors.highlightArea : UIColors.cardBackground,
            borderRadius: 28,
            borderSide: BorderSide(
              color: current ? UIColors.primary40 : UIColors.borders,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StageNumber(
                    number: number,
                    completed: completed,
                    locked: locked,
                  ),
                  const Margin.horizontal(12),
                  Expanded(
                    child: Text(
                      'ЭТАП ${number.toString().padLeft(2, '0')}  ·  $status',
                      style: UITextStyles.monoSemibold11.copyWith(
                        color: locked
                            ? UIColors.secondary1
                            : UIColors.studyAccent,
                      ),
                    ),
                  ),
                  locked
                      ? SvgPicture.asset(
                          UISVGAssets.lockAlt,
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            UIColors.secondary1,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(
                          Icons.arrow_outward_rounded,
                          size: 20,
                          color: UIColors.studyAccent,
                        ),
                ],
              ),
              const Margin.vertical(12),
              Text(title, style: UITextStyles.semibold20),
              const Margin.vertical(0),
              Text(
                summary,
                style: UITextStyles.regular13.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
              if (!locked) ...[
                const Margin.vertical(12),
                Semantics(
                  label:
                      'Прогресс этапа: ${(progress * 100).round()} процентов',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: UIColors.primary20,
                      valueColor: AlwaysStoppedAnimation(UIColors.primary),
                    ),
                  ),
                ),
              ],
              const Margin.vertical(16),
              Text(
                locked ? 'Посмотреть условия  →' : 'Открыть темы  →',
                style: UITextStyles.semibold14.copyWith(
                  color: locked ? UIColors.secondary1 : UIColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageNumber extends StatelessWidget {
  const _StageNumber({
    required this.number,
    required this.completed,
    required this.locked,
  });

  final int number;
  final bool completed;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: locked ? UIColors.pageBackground : UIColors.primary,
      border: locked ? Border.all(color: UIColors.borders) : null,
    ),
    child: completed
        ? Icon(Icons.check_rounded, color: UIColors.badgeText1)
        : Text(
            number.toString().padLeft(2, '0'),
            style: UITextStyles.monoSemibold14.copyWith(
              color: locked ? UIColors.secondary1 : UIColors.badgeText1,
            ),
          ),
  );
}

class CourseSectionPage extends StatelessWidget {
  const CourseSectionPage({
    required this.controller,
    required this.stage,
    super.key,
  });
  final CourseController controller;
  final int stage;

  String? _remainingInBlock(TopicStatus status) {
    final board = TopicBoard(controller.curriculum, rules: controller.rules);
    final missingIds = status.topic.counterOf
        .where((id) => !board.isDone(id, controller.context))
        .toList();
    final remaining = missingIds.length;
    if (remaining <= 0) return null;
    final missingAtoms = controller.curriculum.nodes
        .where((node) => missingIds.contains(node.atom.id))
        .map((node) => node.atom)
        .toList();
    if (remaining == 1) {
      final atom = missingAtoms.firstOrNull;
      final name = atom?.label.isNotEmpty == true ? atom!.label : atom?.display;
      if (name != null && name.isNotEmpty) return 'Осталось освоить: $name';
    }
    final kind = missingAtoms.firstOrNull?.kind;
    final uniform =
        missingAtoms.length == remaining &&
        missingAtoms.every((atom) => atom.kind == kind);
    final forms = switch (uniform ? kind : null) {
      AtomKind.letterForm => ('форму', 'формы', 'форм'),
      AtomKind.haraka || AtomKind.sign => ('знак', 'знака', 'знаков'),
      AtomKind.syllable => ('слог', 'слога', 'слогов'),
      AtomKind.word => ('слово', 'слова', 'слов'),
      AtomKind.concept => ('понятие', 'понятия', 'понятий'),
      null => ('элемент', 'элемента', 'элементов'),
    };
    final tail = remaining % 100;
    final word = tail >= 11 && tail <= 14
        ? forms.$3
        : switch (remaining % 10) {
            1 => forms.$1,
            2 || 3 || 4 => forms.$2,
            _ => forms.$3,
          };
    return 'Осталось освоить $remaining $word';
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: CourseController.stageTitle(stage),
    bottomBar: Obx(() {
      final available =
          controller.byStage[stage]?.any((s) => s.canPractice) ?? false;
      return available
          ? NextButton(
              title: 'Заниматься этой темой',
              enabled: !controller.opening.value,
              onTap: () => controller.openStage(stage),
            )
          : const SizedBox.shrink();
    }),
    builder: (context, insets) => Obx(() {
      final topics = controller.byStage[stage] ?? const <TopicStatus>[];
      final currentIndex = topics.indexWhere(
        (topic) => !topic.isDone && topic.canPractice,
      );
      final current = currentIndex < 0 ? null : topics[currentIndex];
      final remainingInBlock = current == null
          ? null
          : _remainingInBlock(current);
      final progress = controller.progressForStage(stage);
      return ListView(
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          _SectionProgress(
            done: progress.done,
            total: progress.total,
            unit: progress.unit,
            explanation: stage == 1
                ? 'Буква засчитывается, когда освоены все её формы.'
                : 'Один блок можно закреплять за несколько занятий.',
            currentBlock: remainingInBlock == null
                ? null
                : current!.topic.title,
            currentBlockNumber: currentIndex < 0 ? null : currentIndex + 1,
            remainingInBlock: remainingInBlock,
          ),
          const Margin.vertical(24),
          Row(
            children: [
              Expanded(
                child: Text('Блоки раздела', style: UITextStyles.semibold20),
              ),
              Text(
                '${topics.length}',
                style: UITextStyles.monoSemibold13.copyWith(
                  color: UIColors.text.withValues(alpha: .72),
                ),
              ),
            ],
          ),
          const Margin.vertical(12),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: SquircleBorders.squircleBorder(
              color: UIColors.cardBackground,
              borderRadius: 24,
              borderSide: BorderSide(color: UIColors.borders),
            ),
            child: Column(
              children: [
                for (var index = 0; index < topics.length; index++) ...[
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(
                        height: 1,
                        color: UIColors.backgroundShapes1,
                      ),
                    ),
                  _CourseTopicRow(
                    status: topics[index],
                    number: index + 1,
                    current: index == currentIndex,
                    onTap: () => Get.to(
                      () => CourseTopicPage(
                        controller: controller,
                        topicId: topics[index].topic.id,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }),
  );
}

class _SectionProgress extends StatelessWidget {
  const _SectionProgress({
    required this.done,
    required this.total,
    required this.unit,
    required this.explanation,
    required this.currentBlock,
    required this.currentBlockNumber,
    required this.remainingInBlock,
  });

  final int done;
  final int total;
  final String unit;
  final String explanation;
  final String? currentBlock;
  final int? currentBlockNumber;
  final String? remainingInBlock;

  Widget _reveal(Widget child, double fraction, {double offset = 12}) =>
      Opacity(
        opacity: fraction,
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - fraction)),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 880),
      builder: (context, time, child) {
        double phase(double start, double end) => Curves.easeOutCubic.transform(
          ((time - start) / (end - start)).clamp(0.0, 1.0),
        );

        final cardEntrance = phase(0, .55);
        final metricEntrance = phase(.2, .7);
        final ringEntrance = phase(.24, .86);
        final currentBlockEntrance = phase(.48, 1);
        return Opacity(
          opacity: phase(0, .4),
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - cardEntrance)),
            child: Transform.scale(
              alignment: Alignment.topCenter,
              scale: .985 + .015 * cardEntrance,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: SquircleBorders.squircleBorder(
                  color: UIColors.cardBackground,
                  borderRadius: 28,
                  borderSide: BorderSide(color: UIColors.borders),
                  shadows: [
                    BoxShadow(
                      color: UIColors.shadows,
                      blurRadius: 5,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _reveal(
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked =
                                constraints.maxWidth < 220 ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.4;
                            final ring = ProgressRing(
                              value: progress,
                              size: 96,
                              revealFraction: ringEntrance,
                              semanticLabel: '$done из $total $unit',
                            );
                            final metric = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: done.toDouble()),
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animatedDone, child) => Text(
                                    '${(animatedDone * metricEntrance).round()}/$total',
                                    style: UITextStyles.monoBold26,
                                  ),
                                ),
                                const Margin.vertical(0),
                                Text(
                                  unit,
                                  style: UITextStyles.monoRegular12.copyWith(
                                    color: UIColors.text.withValues(alpha: .72),
                                  ),
                                ),
                                const Margin.vertical(8),
                                Text(
                                  explanation,
                                  style: UITextStyles.regular12.copyWith(
                                    color: UIColors.text.withValues(alpha: .72),
                                  ),
                                ),
                              ],
                            );
                            return stacked
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ring,
                                      const Margin.vertical(16),
                                      metric,
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ring,
                                      const Margin.horizontal(20),
                                      Expanded(child: metric),
                                    ],
                                  );
                          },
                        ),
                      ),
                      metricEntrance,
                    ),
                    if (currentBlock != null && remainingInBlock != null)
                      _reveal(
                        Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: UIColors.primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: UIColors.white,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.flag,
                                            size: 16,
                                            color: UIColors.inkSurface,
                                          ),
                                          Margin.horizontal(4),
                                          Text(
                                            'СЕЙЧАС ИЗУЧАЕМ',
                                            style: UITextStyles.monoSemibold11
                                                .copyWith(
                                                  color: UIColors.inkSurface,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Spacer(),
                                    if (currentBlockNumber != null)
                                      Text(
                                        currentBlockNumber!.toString().padLeft(
                                          2,
                                          '0',
                                        ),
                                        style: UITextStyles.monoSemibold14
                                            .copyWith(color: UIColors.white),
                                      ),
                                  ],
                                ),
                                const Margin.vertical(16),
                                Text(
                                  currentBlock!,
                                  style: UITextStyles.semibold22.copyWith(
                                    color: UIColors.white,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  remainingInBlock!,
                                  style: UITextStyles.monoRegular12.copyWith(
                                    color: UIColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        currentBlockEntrance,
                        offset: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CourseTopicRow extends StatelessWidget {
  const _CourseTopicRow({
    required this.status,
    required this.number,
    required this.current,
    required this.onTap,
  });

  final TopicStatus status;
  final int number;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = status.state == TopicState.locked;
    final subtitle = locked
        ? status.hint
        : status.state == TopicState.passedByTest
        ? 'Знания подтверждены · нужно закрепить'
        : status.isDone
        ? 'Освоено · повторить'
        : status.started
        ? 'Изучаем · освоено ${status.done} из ${status.total}'
        : 'Доступно';
    return Semantics(
      button: true,
      label:
          '${status.topic.title}. $subtitle. ${locked ? 'Посмотреть условия' : 'Открыть блок'}',
      child: AppGestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current ? UIColors.primary : UIColors.pageBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: status.isDone
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: UIColors.success,
                      )
                    : Text(
                        number.toString().padLeft(2, '0'),
                        style: UITextStyles.monoSemibold13.copyWith(
                          color: current
                              ? UIColors.white
                              : UIColors.text.withValues(alpha: .72),
                        ),
                      ),
              ),
              const Margin.horizontal(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (current) ...[
                      Text(
                        'СЕЙЧАС',
                        style: UITextStyles.monoBold11.copyWith(
                          color: UIColors.primary,
                        ),
                      ),
                      const Margin.vertical(4),
                    ],
                    Text(status.topic.title, style: UITextStyles.semibold16),
                    const Margin.vertical(4),
                    Text(
                      subtitle,
                      style: UITextStyles.regular13.copyWith(
                        color: UIColors.text.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
              ),
              const Margin.horizontal(8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: locked
                    ? SvgPicture.asset(
                        UISVGAssets.lockAlt,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          UIColors.text.withValues(alpha: .72),
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: UIColors.studyAccent,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseTopicPage extends StatelessWidget {
  const CourseTopicPage({
    required this.controller,
    required this.topicId,
    super.key,
  });
  final CourseController controller;
  final String topicId;

  TopicStatus get status =>
      controller.statuses.firstWhere((s) => s.topic.id == topicId);

  Future<void> _check() async {
    await Get.to(
      () => KnowledgeCheckPage(controller: controller, topic: status.topic),
    );
    await controller.refreshBoard();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Тема',
    bottomBar: Obx(
      () => controller.requiresKnowledgeCheck(status)
          ? NextButton(title: 'Перейти к этой теме', onTap: _check)
          : status.canPractice
          ? NextButton(
              title: status.started ? 'Потренироваться' : 'Начать этот блок',
              enabled: !controller.opening.value,
              onTap: () => controller.open(status),
            )
          : NextButton(title: 'Проверить знания и открыть', onTap: _check),
    ),
    builder: (context, insets) => Obx(() {
      final s = status;
      final atoms = s.topic.counterOf
          .map(
            (id) => controller.curriculum.nodes
                .firstWhereOrNull((n) => n.atom.id == id)
                ?.atom,
          )
          .nonNulls
          .toList();
      final board = TopicBoard(controller.curriculum);
      return ListView(
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          _TopicOverview(status: s),
          if (s.state == TopicState.locked) ...[
            const Margin.vertical(16),
            const _KnowledgeCheckNote(),
          ],
          const Margin.vertical(24),
          Row(
            children: [
              Expanded(
                child: Text('Материал блока', style: UITextStyles.semibold20),
              ),
              BadgeLabel(
                text: '${atoms.length}',
                color: UIColors.primary10,
                textColor: UIColors.primary,
              ),
            ],
          ),
          const Margin.vertical(12),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: atoms.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final atom = atoms[index];
              return _TopicAtomTile(
                atom: atom,
                isDone: board.isDone(atom.id, controller.context),
                onTap: () => Get.to(
                  () => CourseMaterialPage(atoms: atoms, initialIndex: index),
                ),
              );
            },
          ),
        ],
      );
    }),
  );
}

class _TopicOverview extends StatelessWidget {
  const _TopicOverview({required this.status});

  final TopicStatus status;

  @override
  Widget build(BuildContext context) {
    final locked = status.state == TopicState.locked;
    final completed = status.isDone;
    final icon = locked
        ? Icons.lock_outline_rounded
        : completed
        ? Icons.check_rounded
        : Icons.menu_book_rounded;
    final label = locked
        ? 'Пока закрыто'
        : status.state == TopicState.passedByTest
        ? 'Знания подтверждены'
        : completed
        ? 'Освоено'
        : status.started
        ? 'Изучаем'
        : 'Доступно';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 28,
        borderSide: BorderSide(color: UIColors.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeLabel(
                leading: SvgPicture.asset(
                  UISVGAssets.bookFilled,
                  height: 16,
                  colorFilter: ColorFilter.mode(
                    UIColors.primary,
                    BlendMode.srcIn,
                  ),
                ).marginOnly(right: 0),
                text: label,
                color: UIColors.primary10,
                textColor: UIColors.primary,
              ),
            ],
          ),
          const Margin.vertical(8),
          Text(status.topic.title, style: UITextStyles.semibold27),
          const Margin.vertical(16),
          if (locked)
            Text(
              status.hint,
              style: UITextStyles.regular15.copyWith(
                color: UIColors.secondary2,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    completed ? 'Все элементы освоены' : 'Прогресс темы',
                    style: UITextStyles.regular13.copyWith(
                      color: UIColors.secondary2,
                    ),
                  ),
                ),
                Text(
                  '${status.done} из ${status.total}',
                  style: UITextStyles.monoSemibold13,
                ),
              ],
            ),
            const Margin.vertical(12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.progress,
                minHeight: 8,
                backgroundColor: UIColors.primary10,
                valueColor: AlwaysStoppedAnimation(UIColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeCheckNote extends StatelessWidget {
  const _KnowledgeCheckNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: SquircleBorders.squircleBorder(
      color: UIColors.primary10,
      borderRadius: 20,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.tips_and_updates_outlined,
          color: UIColors.primary,
          size: 24,
        ),
        const Margin.horizontal(12),
        Expanded(
          child: Text(
            'Уже знакомы с темой? Проверьте знания. Каждый подтверждённый элемент сохранится.',
            style: UITextStyles.regular15,
          ),
        ),
      ],
    ),
  );
}

class _TopicAtomTile extends StatelessWidget {
  const _TopicAtomTile({
    required this.atom,
    required this.isDone,
    required this.onTap,
  });

  final Atom atom;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    onTap: onTap,
    label:
        '${atom.label.isEmpty ? atom.display : atom.label}, ${isDone ? 'освоено' : 'впереди'}',
    child: ExcludeSemantics(
      child: AppGestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: SquircleBorders.squircleBorder(
            color: UIColors.cardBackground,
            borderRadius: 20,
            borderSide: BorderSide(color: UIColors.borders),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 64,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: atom.kind == AtomKind.concept
                      ? SvgPicture.asset(
                          UISVGAssets.bookFilled,
                          width: 32,
                          height: 32,
                          colorFilter: ColorFilter.mode(
                            UIColors.primary,
                            BlendMode.srcIn,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            atom.display,
                            textDirection: TextDirection.rtl,
                            style: UITextStyles.dgFasehRegular(
                              48,
                            ).copyWith(color: UIColors.primary),
                          ),
                        ),
                ),
              ),
              const Margin.vertical(8),
              Expanded(
                child: Text(
                  atom.label.isEmpty ? atom.display : atom.label,
                  style: UITextStyles.semibold14,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.turn_sharp_right_outlined,
                    size: 14,
                    color: isDone ? UIColors.success : UIColors.secondary2,
                  ),
                  const Margin.horizontal(4),
                  Text(
                    isDone ? 'Освоено' : 'Впереди',
                    style: UITextStyles.regular12.copyWith(
                      color: isDone ? UIColors.success : UIColors.secondary2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
