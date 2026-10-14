import 'package:arabic_tajweed_app/app/pages/streak/weekly_streak_page.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_learned_popup.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'debug_menu_widgets.dart';
import 'debug_page_controller.dart';
import 'server_url_dialog.dart';

enum DebugMenuSection {
  settings(
    'Настройки',
    'Сервер, произношение и цветовая схема',
    Icons.tune_rounded,
  ),
  course(
    'Курс и прогресс',
    'Экраны курса, алфавит и состояния атомов',
    Icons.school_outlined,
  ),
  exercises(
    'Упражнения',
    'Буквы, огласовки, сборка и произношение',
    Icons.extension_outlined,
  ),
  components(
    'Компоненты и анимации',
    'Виджеты, эффекты и награды',
    Icons.widgets_outlined,
  ),
  reset(
    'Сброс',
    'Дата приложения и учебный прогресс',
    Icons.restart_alt_rounded,
  );

  const DebugMenuSection(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;

  String get pageTitle => switch (this) {
    course => 'Курс',
    components => 'Компоненты',
    _ => title,
  };
}

/// Подраздел отладки использует общий контроллер корневого меню.
class DebugSectionPage extends GetView<DebugController> {
  const DebugSectionPage({required this.section, super.key});

  final DebugMenuSection section;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: section.pageTitle,
    builder: (_, insets) =>
        ListView(padding: insets, children: _content(context)),
  );

  List<Widget> _content(BuildContext context) => switch (section) {
    DebugMenuSection.settings => [
      DebugMenuGroup(
        children: [
          Obx(
            () => DebugMenuTile(
              icon: Icons.dns_outlined,
              title: 'Адрес сервера',
              subtitle: controller.serverUrl.value,
              onTap: () => _editServerUrl(context),
            ),
          ),
          Obx(
            () => DebugMenuTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Произношение в уроках',
              subtitle: controller.pronunciationEnabled.value
                  ? 'Включено · обязательное задание'
                  : 'Отключено до перезапуска приложения',
              onTap: controller.togglePronunciation,
            ),
          ),
          ValueListenableBuilder<AppColorScheme>(
            valueListenable: UIColors.selection,
            builder: (context, scheme, _) => DebugMenuTile(
              icon: Icons.palette_outlined,
              title: 'Цветовая схема',
              subtitle: _colorSchemeName(scheme),
              onTap: () => _chooseColorScheme(context),
            ),
          ),
        ],
      ),
    ],
    DebugMenuSection.course => [
      DebugMenuGroup(
        children: [
          DebugMenuTile(
            icon: Icons.grid_view_rounded,
            title: 'Курс',
            subtitle: 'Главный экран с темами',
            onTap: controller.openCourse,
          ),
          DebugMenuTile(
            icon: Icons.school_outlined,
            title: 'Урок',
            subtitle: 'Точка входа в курс',
            onTap: controller.openLesson,
          ),
          DebugMenuTile(
            icon: Icons.local_fire_department_outlined,
            title: 'Недельный стрик',
            subtitle: 'Поздравление с семью днями занятий',
            onTap: () => Get.toNamed(WeeklyStreakPage.routeName),
          ),
          DebugMenuTile(
            icon: Icons.menu_book_outlined,
            title: 'Алфавит · буква',
            subtitle: 'Экран знакомства с буквой',
            onTap: controller.openAlphabetLetter,
          ),
          DebugMenuTile(
            icon: Icons.grain_outlined,
            title: 'Атомы',
            subtitle: 'Состояние каждого атома по логу',
            onTap: controller.openAtomProgress,
          ),
        ],
      ),
    ],
    DebugMenuSection.exercises => [
      DebugMenuGroup(
        title: 'Буквы и огласовки',
        children: [
          DebugMenuTile(
            icon: Icons.draw_outlined,
            title: 'Обводка букв',
            subtitle: 'Упражнение с обводкой',
            onTap: controller.openTracing,
          ),
          DebugMenuTile(
            icon: Icons.view_carousel_outlined,
            title: 'Формы буквы',
            subtitle: 'Слоты, плитки и анимации',
            onTap: controller.openFormSequence,
          ),
          DebugMenuTile(
            icon: Icons.volume_up_rounded,
            title: 'Огласовки по звуку',
            subtitle: 'Три звуковых слота и три огласовки',
            onTap: controller.openHarakaSequence,
          ),
          DebugMenuTile(
            icon: Icons.gesture_rounded,
            title: 'Холст огласовок',
            subtitle: 'Контур, память и дорисовка по звуку',
            onTap: controller.openHarakaDrawing,
          ),
          DebugMenuTile(
            icon: Icons.checklist_rounded,
            title: 'Одинаковая огласовка',
            subtitle: 'Послушать и выбрать все подходящие слоги',
            onTap: controller.openHarakaMatch,
          ),
        ],
      ),
      const Margin.vertical(32),
      DebugMenuGroup(
        title: 'Сборка',
        children: [
          DebugMenuTile(
            icon: Icons.extension_outlined,
            title: 'Сборка слога',
            subtitle: 'Послушать, выбрать букву и огласовку',
            onTap: controller.openSyllableBuild,
          ),
          DebugMenuTile(
            icon: Icons.extension_rounded,
            title: 'Дострой соединение',
            subtitle: 'Добавить форму буквы и огласовку по звуку',
            onTap: controller.openConnectionBuild,
          ),
          DebugMenuTile(
            icon: Icons.join_left_rounded,
            title: 'Собери слово по шагам',
            subtitle: 'Форма и огласовка каждой буквы справа налево',
            onTap: controller.openWordBuild,
          ),
        ],
      ),
      const Margin.vertical(32),
      DebugMenuGroup(
        title: 'Произношение',
        children: [
          DebugMenuTile(
            icon: Icons.mic_none_rounded,
            title: 'Произношение',
            subtitle: 'Ответ сервера на произнесённую букву',
            onTap: controller.openPronunciation,
          ),
          DebugMenuTile(
            icon: Icons.graphic_eq_rounded,
            title: 'Задание на произношение',
            subtitle: 'Карточка урока и ожидание проверки',
            onTap: controller.openPronunciationExercise,
          ),
          DebugMenuTile(
            icon: Icons.record_voice_over_rounded,
            title: 'Чтение слога вслух',
            subtitle: 'Запись и проверка буквы с огласовкой',
            onTap: controller.openSyllablePronunciation,
          ),
          DebugMenuTile(
            icon: Icons.record_voice_over_rounded,
            title: 'Чтение слова вслух',
            subtitle: 'Проверка произношения из блока «Читаем слова»',
            onTap: controller.openWordPronunciation,
          ),
        ],
      ),
    ],
    DebugMenuSection.components => [
      DebugMenuGroup(
        title: 'Виджеты',
        children: [
          DebugMenuTile(
            icon: Icons.widgets_outlined,
            title: 'App Widgets',
            subtitle: 'Демо виджетов приложения',
            onTap: controller.openAppWidgetsPage,
          ),
          DebugMenuTile(
            icon: Icons.mic_rounded,
            title: 'Виджет записи',
            subtitle: 'Запись, таймер, волна и проверка',
            onTap: controller.openPronunciationRecorder,
          ),
        ],
      ),
      const Margin.vertical(32),
      DebugMenuGroup(
        title: 'Анимации и награды',
        children: [
          DebugMenuTile(
            icon: Icons.stars_rounded,
            title: 'Полёт между звёздами',
            subtitle: 'Полноэкранная анимация точек',
            onTap: controller.openStarfield,
          ),
          DebugMenuTile(
            icon: Icons.waves_rounded,
            title: 'Светящаяся волна',
            subtitle: 'Точки, перемычки и светящиеся капсулы',
            onTap: controller.openGlowWave,
          ),
          DebugMenuTile(
            icon: Icons.radar_rounded,
            title: 'Орбитальные кольца',
            subtitle: 'Кольца и вращающиеся штрихи',
            onTap: controller.openOrbitalRings,
          ),
          DebugMenuTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Буква изучена',
            subtitle: 'Поп-ап с анимацией Rive',
            onTap: () async {
              final curriculum = await const CurriculumLoader().load();
              if (!context.mounted) return;
              await showLetterLearnedPopup(
                context,
                atom: curriculum.baseLetters.first,
              );
            },
          ),
        ],
      ),
    ],
    DebugMenuSection.reset => [
      DebugMenuGroup(
        children: [
          if (kDebugMode)
            DebugMenuTile(
              icon: Icons.calendar_today_outlined,
              title: 'Сбросить дату',
              subtitle: 'Вернуть текущую дату устройства',
              onTap: controller.resetDebugToday,
            ),
          DebugMenuTile(
            icon: Icons.restart_alt_rounded,
            title: 'Сбросить прогресс',
            subtitle: 'Стереть лог и начать курс заново',
            onTap: controller.resetProgress,
            destructive: true,
          ),
        ],
      ),
    ],
  };

  static String _colorSchemeName(AppColorScheme scheme) => switch (scheme) {
    AppColorScheme.system => 'Как в системе',
    AppColorScheme.light => 'Светлая',
    AppColorScheme.dark => 'Тёмная',
    AppColorScheme.dark2 => 'Dark 2',
  };

  Future<void> _chooseColorScheme(BuildContext context) async {
    final selected = await showDialog<AppColorScheme>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Цветовая схема'),
        children: [
          for (final scheme in AppColorScheme.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(scheme),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_colorSchemeName(scheme)),
                  if (UIColors.selection.value == scheme)
                    const Icon(Icons.check_rounded),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) await controller.setColorScheme(selected);
  }

  Future<void> _editServerUrl(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => ServerUrlDialog(initialUrl: controller.serverUrl.value),
    );
    if (value != null) await controller.saveServerUrl(value);
  }
}
