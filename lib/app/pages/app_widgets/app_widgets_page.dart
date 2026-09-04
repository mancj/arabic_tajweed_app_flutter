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
      builder: (context, insets) => ListView(
        padding: insets,
        children: const [
          LetterWidgetCard(letter: 'ق', question: 'Как произносится буква ق?'),
        ],
      ),
    );
  }
}
