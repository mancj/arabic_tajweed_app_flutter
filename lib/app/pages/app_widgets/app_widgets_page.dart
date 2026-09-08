import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';

import 'app_widgets_controller.dart';

export 'app_widgets_binding.dart';
export 'app_widgets_controller.dart';

/// Витрина виджетов приложения: сюда добавляются демо-секции из `ui_kit`,
/// чтобы смотреть их вне контекста конкретного экрана.
class AppWidgetsPage extends GetView<AppWidgetsController> {
  static const routeName = '/app_widgets';

  const AppWidgetsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'App Widgets',
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: const Column(
          children: [
            LetterWidgetCard(
              labelText: 'Вопрос',
              isArabic: true,
              letter: 'ق',
              question: 'Какая это буква?',
              subtitle: 'в начале',
            ),
            Margin.vertical(8),
            LetterWidgetCard(
              labelText: 'Буква',
              isArabic: true,
              letter: 'ص',
              subtitle: 'в конце',
            ),
            Margin.vertical(8),
            LetterWidgetCard(
              labelText: 'Вопрос',
              isArabic: false,
              letter: 'Ба',
              question: 'Как произносится буква Ба?',
            ),
          ],
        ),
      ),
    );
  }
}
