import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../../widgets/ui_kit/rule_card.dart';
import '../debug/debug_page.dart';
import 'course_controller.dart';
import 'course_path_page.dart';

export 'course_binding.dart';
export 'course_controller.dart';

class CoursePage extends GetView<CourseController> {
  static const routeName = '/course';
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Моё обучение',
    showBackButton: false,
    bottomBar: Obx(
      () => NextButton(
        title: 'Начать занятие',
        enabled: controller.canStart,
        onTap: controller.continueCourse,
      ),
    ),
    builder: (context, insets) => Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.loadError.value != null) {
        return Padding(
          padding: insets.copyWith(top: insets.top + 24),
          child: Column(
            children: [
              const Text(
                'Не удалось подготовить занятие',
                style: UITextStyles.semiboldText,
              ),
              const Margin.vertical(16),
              NextButton(
                title: 'Попробовать ещё раз',
                onTap: controller.refreshBoard,
              ),
            ],
          ),
        );
      }
      return SingleChildScrollView(
        padding: insets.copyWith(top: insets.top + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Сегодня', style: UITextStyles.hint),
            const Margin.vertical(12),
            RuleCard(
              title: controller.lessonTitle,
              badge: controller.nextPlan.value?.newAtoms.isEmpty ?? true
                  ? 'Закрепление'
                  : 'Новое и повторение',
              text: controller.lessonDescription,
            ),
            const Margin.vertical(24),
            CourseLink(
              title: 'Мой путь',
              subtitle: 'Темы и ваши знания',
              icon: Icons.route_rounded,
              onTap: () => Get.to(() => CoursePathPage(controller: controller)),
            ),
            if (kDebugMode) ...[
              const Margin.vertical(24),
              TextButton(
                onPressed: () async {
                  await Get.toNamed(DebugPage.routeName);
                  await controller.refreshBoard();
                },
                child: const Text('Меню отладки', style: UITextStyles.hint),
              ),
            ],
          ],
        ),
      );
    }),
  );
}
