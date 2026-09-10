import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/atom.dart';
import '../../../domain/topic_board.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/squircle_borders.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/rule_card.dart';
import 'course_controller.dart';
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
          padding: const EdgeInsets.all(20),
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
                    Text(title, style: UITextStyles.semiboldText),
                    const Margin.vertical(6),
                    Text(subtitle, style: UITextStyles.hint),
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
    builder: (context, insets) => Obx(
      () => ListView(
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          for (final entry in controller.byStage.entries) ...[
            CourseLink(
              title: CourseController.stageTitle(entry.key),
              subtitle: _summary(entry.key, entry.value),
              onTap: () => Get.to(
                () =>
                    CourseSectionPage(controller: controller, stage: entry.key),
              ),
            ),
            const Margin.vertical(12),
          ],
        ],
      ),
    ),
  );

  String _summary(int stage, List<TopicStatus> topics) {
    if (stage == 1) {
      final letters = controller.curriculum.formsByLetter.keys;
      final done = letters.where(controller.context.isLetterKnown).length;
      return 'Освоено букв: $done из ${letters.length}';
    }
    if (!topics.any((t) => t.canPractice)) {
      return 'Пока закрыто · посмотреть условия';
    }
    final done = topics.where((t) => t.isDone).length;
    return done == topics.length
        ? 'Освоено · можно повторить'
        : 'Освоено блоков: $done из ${topics.length}';
  }
}

class CourseSectionPage extends StatelessWidget {
  const CourseSectionPage({
    required this.controller,
    required this.stage,
    super.key,
  });
  final CourseController controller;
  final int stage;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: CourseController.stageTitle(stage),
    bottomBar: Obx(() {
      final available = controller.byStage[stage]!.any((s) => s.canPractice);
      return available
          ? NextButton(
              title: 'Заниматься этой темой',
              enabled: !controller.opening.value,
              onTap: () => controller.openStage(stage),
            )
          : const SizedBox.shrink();
    }),
    builder: (context, insets) => Obx(
      () => ListView(
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          const Text(
            'Каждый блок можно закреплять за несколько занятий.',
            style: UITextStyles.hint,
          ),
          const Margin.vertical(16),
          for (final status in controller.byStage[stage]!) ...[
            CourseLink(
              title: status.topic.title,
              subtitle: status.state == TopicState.locked
                  ? status.hint
                  : status.isDone
                  ? 'Освоено · повторить'
                  : status.started
                  ? 'Изучаем · освоено ${status.done} из ${status.total}'
                  : 'Доступно',
              icon: status.state == TopicState.locked
                  ? Icons.lock_outline_rounded
                  : status.isDone
                  ? Icons.check_rounded
                  : Icons.chevron_right_rounded,
              onTap: () => Get.to(
                () => CourseTopicPage(
                  controller: controller,
                  topicId: status.topic.id,
                ),
              ),
            ),
            const Margin.vertical(12),
          ],
        ],
      ),
    ),
  );
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
      () => status.canPractice
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
      return ListView(
        padding: insets.copyWith(top: insets.top + 24),
        children: [
          RuleCard(
            title: s.topic.title,
            badge: s.state == TopicState.locked
                ? 'Пока закрыто'
                : s.isDone
                ? 'Освоено'
                : 'Доступно',
            text: s.state == TopicState.locked
                ? s.hint
                : 'Освоено: ${s.done} из ${s.total}',
          ),
          const Margin.vertical(20),
          const Text('Материал блока', style: UITextStyles.semiboldText),
          const Margin.vertical(12),
          for (final atom in atoms)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(atom.label, style: UITextStyles.regularText),
                  ),
                  Text(
                    TopicBoard(
                          controller.curriculum,
                        ).isDone(atom.id, controller.context)
                        ? 'Освоено'
                        : 'Впереди',
                    style: UITextStyles.hint,
                  ),
                ],
              ),
            ),
          if (s.state != TopicState.locked) ...[
            const Margin.vertical(12),
            ExpansionTile(
              title: const Text('Объяснения', style: UITextStyles.semiboldText),
              children: [
                for (final atom in atoms)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RuleCard(
                      title: atom.label,
                      text: atom.note,
                      child: atom.kind == AtomKind.concept
                          ? null
                          : Text(
                              atom.display,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: UITextStyles.fontScheherazadeNew,
                                fontSize: 64,
                                color: UIColors.text,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            const Margin.vertical(16),
            const Text(
              'Уже знакомы с этим материалом? Проверим необходимые знания. Подтверждённое сохранится, даже если останутся пробелы.',
              style: UITextStyles.regularText,
            ),
          ],
        ],
      );
    }),
  );
}
