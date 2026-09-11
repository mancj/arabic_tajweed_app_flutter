import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/next_button.dart';
import '../debug/debug_page.dart';
import 'course_controller.dart';
import 'course_dashboard.dart';

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
        icon: Icons.play_arrow_rounded,
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
              Text(
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
            Text(
              controller.allDone
                  ? 'Сохраним знания\nв практике'
                  : controller.hasStarted
                  ? 'Продолжим знакомство с буквами'
                  : 'Познакомимся\nс первыми буквами',
              style: UITextStyles.pageTitleSemibold.copyWith(
                fontSize: 29,
                height: 1.16,
                letterSpacing: -.8,
              ),
            ),
            const Margin.vertical(20),
            CourseActivityWeek(
              days: controller.activityDays.toSet(),
              today: DateTime.now(),
            ),
            const Margin.vertical(24),
            CourseLessonPreview(controller: controller),
            const Margin.vertical(14),
            CourseOverview(controller: controller),
            const Margin.vertical(24),
            TextButton(
              onPressed: () async {
                await Get.toNamed(DebugPage.routeName);
                await controller.refreshBoard();
              },
              child: Text('Меню отладки', style: UITextStyles.hint),
            ),
          ],
        ),
      );
    }),
  );
}
