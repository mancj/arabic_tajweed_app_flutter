import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/atom.dart';
import '../../../domain/topic_board.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/squircle_borders.dart';
import '../../widgets/ui_kit/badge_label.dart';
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
          Text(
            'Каждый блок можно закреплять за несколько занятий.',
            style: UITextStyles.regular12.copyWith(color: UIColors.secondary2),
          ),
          const Margin.vertical(16),
          for (final status in controller.byStage[stage]!) ...[
            CourseLink(
              title: status.topic.title,
              subtitle: status.state == TopicState.locked
                  ? status.hint
                  : status.state == TopicState.passedByTest
                  ? 'Знания подтверждены · нужно закрепить'
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
              );
            },
          ),
          if (s.state != TopicState.locked) ...[
            const Margin.vertical(24),
            ExpansionTile(
              title: Text('Объяснения', style: UITextStyles.semibold16),
              leading: Icon(Icons.menu_book_rounded, color: UIColors.primary),
              backgroundColor: UIColors.cardBackground,
              collapsedBackgroundColor: UIColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: UIColors.borders),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: UIColors.borders),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                              style: UITextStyles.arabicRegular64,
                            ),
                    ),
                  ),
              ],
            ),
          ],
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
        color: UIColors.highlightArea,
        borderRadius: 28,
        borderSide: BorderSide(color: UIColors.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UIColors.primary10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: UIColors.primary, size: 24),
              ),
              const Margin.horizontal(12),
              BadgeLabel(
                text: label,
                color: UIColors.primary10,
                textColor: UIColors.primary,
              ),
            ],
          ),
          const Margin.vertical(24),
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
  const _TopicAtomTile({required this.atom, required this.isDone});

  final Atom atom;
  final bool isDone;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '${atom.label.isEmpty ? atom.display : atom.label}, ${isDone ? 'освоено' : 'впереди'}',
    child: ExcludeSemantics(
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
                alignment: Alignment.centerLeft,
                child: atom.kind == AtomKind.concept
                    ? Icon(
                        Icons.menu_book_rounded,
                        size: 32,
                        color: UIColors.primary,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          atom.display,
                          textDirection: TextDirection.rtl,
                          style: UITextStyles.arabicRegular48Compact.copyWith(
                            color: UIColors.primary,
                          ),
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
                  isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
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
  );
}
