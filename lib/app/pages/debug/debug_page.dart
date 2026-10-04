import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/diagnostics/app_diagnostics.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_learned_popup.dart';
import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:arabic_tajweed_app/data/rest/api_config.dart';

import 'debug_page_controller.dart';

export 'debug_page_binding.dart';
export 'debug_page_controller.dart';

/// Меню служебных экранов, на которые ещё нет обычной навигации.
class DebugPage extends GetView<DebugController> {
  static const routeName = '/debug';

  const DebugPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Отладка',
      builder: (_, insets) => ListView(
        padding: insets,
        children: [
          const _DebugIntroduction(),
          const Margin.vertical(24),
          _DebugFeaturedTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TalkerScreen(
                  talker: AppDiagnostics.talker,
                  appBarTitle: 'Логи приложения',
                ),
              ),
            ),
          ),
          const Margin.vertical(32),
          _DebugSection(
            number: '01',
            title: 'Настройки и данные',
            children: [
              Obx(
                () => _DebugTile(
                  icon: Icons.dns_outlined,
                  title: 'Адрес сервера',
                  subtitle: controller.serverUrl.value,
                  onTap: () => _editServerUrl(context),
                ),
              ),
              Obx(
                () => _DebugTile(
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
                builder: (context, scheme, _) => _DebugTile(
                  icon: Icons.palette_outlined,
                  title: 'Цветовая схема',
                  subtitle: _colorSchemeName(scheme),
                  onTap: () => _chooseColorScheme(context),
                ),
              ),
              _DebugTile(
                icon: Icons.grain_outlined,
                title: 'Атомы',
                subtitle: 'Состояние каждого атома по логу',
                onTap: controller.openAtomProgress,
              ),
            ],
          ),
          const Margin.vertical(32),
          _DebugSection(
            number: '02',
            title: 'Экраны курса',
            children: [
              _DebugTile(
                icon: Icons.grid_view_rounded,
                title: 'Курс',
                subtitle: 'Главный экран с темами',
                onTap: controller.openCourse,
              ),
              _DebugTile(
                icon: Icons.school_outlined,
                title: 'Урок',
                subtitle: 'Точка входа в курс',
                onTap: controller.openLesson,
              ),
              _DebugTile(
                icon: Icons.menu_book_outlined,
                title: 'Алфавит · буква',
                subtitle: 'Экран знакомства с буквой',
                onTap: controller.openAlphabetLetter,
              ),
              _DebugTile(
                icon: Icons.draw_outlined,
                title: 'Обводка букв',
                subtitle: 'Упражнение с обводкой',
                onTap: controller.openTracing,
              ),
              _DebugTile(
                icon: Icons.gesture_rounded,
                title: 'Холст огласовок',
                subtitle: 'Контур, память и дорисовка по звуку',
                onTap: controller.openHarakaDrawing,
              ),
              _DebugTile(
                icon: Icons.mic_none_rounded,
                title: 'Произношение',
                subtitle: 'Ответ сервера на произнесённую букву',
                onTap: controller.openPronunciation,
              ),
              _DebugTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Задание на произношение',
                subtitle: 'Карточка урока и ожидание проверки',
                onTap: controller.openPronunciationExercise,
              ),
              _DebugTile(
                icon: Icons.checklist_rounded,
                title: 'Одинаковая огласовка',
                subtitle: 'Послушать и выбрать все подходящие слоги',
                onTap: controller.openHarakaMatch,
              ),
              _DebugTile(
                icon: Icons.extension_outlined,
                title: 'Сборка слога',
                subtitle: 'Послушать, выбрать букву и огласовку',
                onTap: controller.openSyllableBuild,
              ),
              _DebugTile(
                icon: Icons.record_voice_over_rounded,
                title: 'Чтение слога вслух',
                subtitle: 'Запись и проверка буквы с огласовкой',
                onTap: controller.openSyllablePronunciation,
              ),
            ],
          ),
          const Margin.vertical(32),
          _DebugSection(
            number: '03',
            title: 'Компоненты',
            children: [
              _DebugTile(
                icon: Icons.widgets_outlined,
                title: 'App Widgets',
                subtitle: 'Демо виджетов приложения',
                onTap: controller.openAppWidgetsPage,
              ),
              _DebugTile(
                icon: Icons.view_carousel_outlined,
                title: 'Формы буквы',
                subtitle: 'Слоты, плитки и анимации',
                onTap: controller.openFormSequence,
              ),
              _DebugTile(
                icon: Icons.volume_up_rounded,
                title: 'Огласовки по звуку',
                subtitle: 'Три звуковых слота и три огласовки',
                onTap: controller.openHarakaSequence,
              ),
              _DebugTile(
                icon: Icons.stars_rounded,
                title: 'Полёт между звёздами',
                subtitle: 'Полноэкранная анимация точек',
                onTap: controller.openStarfield,
              ),
              _DebugTile(
                icon: Icons.waves_rounded,
                title: 'Светящаяся волна',
                subtitle: 'Точки, перемычки и светящиеся капсулы',
                onTap: controller.openGlowWave,
              ),
              _DebugTile(
                icon: Icons.mic_rounded,
                title: 'Виджет записи',
                subtitle: 'Запись, таймер, волна и проверка',
                onTap: controller.openPronunciationRecorder,
              ),
              _DebugTile(
                icon: Icons.radar_rounded,
                title: 'Орбитальные кольца',
                subtitle: 'Кольца и вращающиеся штрихи',
                onTap: controller.openOrbitalRings,
              ),
              _DebugTile(
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
          const Margin.vertical(32),
          _DebugSection(
            number: '04',
            title: 'Сброс',
            children: [
              _DebugTile(
                icon: Icons.restart_alt_rounded,
                title: 'Сбросить прогресс',
                subtitle: 'Стереть лог и начать курс заново',
                onTap: controller.resetProgress,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

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

class _DebugIntroduction extends StatelessWidget {
  const _DebugIntroduction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ВНУТРЕННИЕ ИНСТРУМЕНТЫ',
            style: UITextStyles.monoSemibold11.copyWith(
              color: UIColors.primary,
            ),
          ),
          const Margin.vertical(8),
          Text('Всё для проверки', style: UITextStyles.semibold28),
          const Margin.vertical(8),
          Text(
            'Логи, настройки и быстрый доступ к экранам приложения.',
            style: UITextStyles.regular15.copyWith(color: UIColors.secondary2),
          ),
        ],
      ),
    );
  }
}

class _DebugFeaturedTile extends StatelessWidget {
  final VoidCallback onTap;

  const _DebugFeaturedTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: UIColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: UIColors.primary20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DebugIcon(icon: Icons.terminal_rounded, prominent: true),
            const Margin.horizontal(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ДИАГНОСТИКА',
                    style: UITextStyles.monoSemibold11.copyWith(
                      color: UIColors.primary,
                    ),
                  ),
                  const Margin.vertical(8),
                  Text('Логи приложения', style: UITextStyles.semibold20),
                  const Margin.vertical(4),
                  Text(
                    'Ошибки Flutter и Rive. Просмотр и копирование записей.',
                    style: UITextStyles.regular13.copyWith(
                      color: UIColors.secondary2,
                    ),
                  ),
                  const Margin.vertical(16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Открыть журнал',
                        style: UITextStyles.semibold13.copyWith(
                          color: UIColors.primary,
                        ),
                      ),
                      const Margin.horizontal(4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: UIColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugSection extends StatelessWidget {
  final String number;
  final String title;
  final List<Widget> children;

  const _DebugSection({
    required this.number,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                number,
                style: UITextStyles.monoSemibold11.copyWith(
                  color: UIColors.primary,
                ),
              ),
              const Margin.horizontal(12),
              Text(title, style: UITextStyles.semibold17),
            ],
          ),
        ),
        const Margin.vertical(12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: UIColors.cardBackground,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 80, right: 24),
                      color: UIColors.pageBackground,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DebugIcon extends StatelessWidget {
  final IconData icon;
  final bool prominent;
  final bool destructive;

  const _DebugIcon({
    required this.icon,
    this.prominent = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? UIColors.error : UIColors.primary;
    return Container(
      width: prominent ? 48 : 40,
      height: prominent ? 48 : 40,
      decoration: BoxDecoration(
        color: destructive
            ? UIColors.error.withValues(alpha: .1)
            : UIColors.primary10,
        borderRadius: BorderRadius.circular(prominent ? 16 : 12),
      ),
      child: Icon(icon, size: prominent ? 24 : 20, color: color),
    );
  }
}

class _DebugTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _DebugTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            _DebugIcon(icon: icon, destructive: destructive),
            const Margin.horizontal(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: UITextStyles.semibold15.copyWith(
                      color: destructive ? UIColors.error : UIColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const Margin.vertical(4),
                    Text(
                      subtitle!,
                      style: UITextStyles.regular12.copyWith(
                        color: UIColors.secondary2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Margin.horizontal(8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: UIColors.secondary2,
            ),
          ],
        ),
      ),
    );
  }
}
