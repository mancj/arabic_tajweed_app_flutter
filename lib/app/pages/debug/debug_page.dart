import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/page_title.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'debug_page_controller.dart';

export 'debug_page_binding.dart';
export 'debug_page_controller.dart';

/// Точка входа после сплэша в дебажных сборках: отсюда открываются экраны,
/// на которые ещё нет обычной навигации.
class DebugPage extends GetView<DebugController> {
  static const routeName = '/debug';

  const DebugPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Debug',
      builder: (_, insets) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: insets,
              children: [
                _DebugTile(
                  title: 'Сбросить прогресс',
                  subtitle: 'Стереть лог и начать курс заново',
                  onTap: controller.resetProgress,
                ),
                _DebugTile(
                  title: 'Курс',
                  subtitle: 'Главный экран с темами',
                  onTap: controller.openCourse,
                ),
                _DebugTile(
                  title: 'Урок',
                  subtitle: 'Точка входа в курс',
                  onTap: controller.openLesson,
                ),
                _DebugTile(
                  title: 'Алфавит · буква',
                  subtitle: 'Экран знакомства с буквой',
                  onTap: controller.openAlphabetLetter,
                ),
                _DebugTile(
                  title: 'Home',
                  subtitle: 'Обводка букв',
                  onTap: controller.openHome,
                ),
                _DebugTile(
                  title: 'App Widgets',
                  subtitle: 'Демо виджетов приложения',
                  onTap: controller.openAppWidgetsPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _DebugTile({required this.title, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppGestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: UIColors.itemBackground,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: UITextStyles.semibold17),
                    if (subtitle != null) ...[
                      const Margin.vertical(4),
                      Text(subtitle!, style: UITextStyles.hint),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: UIColors.secondary3),
            ],
          ),
        ),
      ),
    );
  }
}
