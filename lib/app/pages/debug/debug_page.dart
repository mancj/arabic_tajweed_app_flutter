import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/data/rest/api_config.dart';

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
                Obx(
                  () => _DebugTile(
                    title: 'Адрес сервера',
                    subtitle: controller.serverUrl.value,
                    onTap: () => _editServerUrl(context),
                  ),
                ),
                _DebugTile(
                  title: 'Сбросить прогресс',
                  subtitle: 'Стереть лог и начать курс заново',
                  onTap: controller.resetProgress,
                ),
                _DebugTile(
                  title: 'Атомы',
                  subtitle: 'Состояние каждого атома по логу',
                  onTap: controller.openAtomProgress,
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
                  title: 'Обводка букв',
                  subtitle: 'Обводка букв',
                  onTap: controller.openTracing,
                ),
                _DebugTile(
                  title: 'Произношение',
                  subtitle: 'Назвать любую букву и увидеть ответ сервера',
                  onTap: controller.openPronunciation,
                ),
                _DebugTile(
                  title: 'App Widgets',
                  subtitle: 'Демо виджетов приложения',
                  onTap: controller.openAppWidgetsPage,
                ),
                _DebugTile(
                  title: 'Формы буквы',
                  subtitle: 'Тест слотов, плиток и анимаций',
                  onTap: controller.openFormSequence,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editServerUrl(BuildContext context) async {
    final textController = TextEditingController(
      text: controller.serverUrl.value,
    );
    final formKey = GlobalKey<FormState>();

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Адрес сервера'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'IP-адрес и порт',
              hintText: '192.168.1.10:8765',
            ),
            validator: (value) {
              try {
                ApiConfig.normalizeBaseUrl(value ?? '');
                return null;
              } on FormatException catch (error) {
                return error.message.toString();
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(textController.text);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (value != null) await controller.saveServerUrl(value);
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
            color: UIColors.cardBackground,
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
              Icon(Icons.chevron_right, color: UIColors.secondary2),
            ],
          ),
        ),
      ),
    );
  }
}
