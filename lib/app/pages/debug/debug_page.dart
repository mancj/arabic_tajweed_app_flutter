import 'package:arabic_tajweed_app/app/diagnostics/app_diagnostics.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'debug_menu_widgets.dart';
import 'debug_section_page.dart';

export 'debug_page_binding.dart';
export 'debug_page_controller.dart';

/// Меню служебных экранов, на которые ещё нет обычной навигации.
class DebugPage extends StatelessWidget {
  static const routeName = '/debug';

  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Отладка',
      builder: (_, insets) => ListView(
        padding: insets,
        children: [
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
          DebugMenuGroup(
            title: 'Разделы',
            children: [
              for (final section in DebugMenuSection.values)
                DebugMenuTile(
                  icon: section.icon,
                  title: section.title,
                  subtitle: section.subtitle,
                  onTap: () => Get.to<void>(
                    () => DebugSectionPage(section: section),
                    routeName: '/debug/${section.name}',
                  ),
                ),
            ],
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
    return Semantics(
      button: true,
      label: 'Логи приложения',
      hint: 'Просмотр и копирование записей',
      excludeSemantics: true,
      onTap: onTap,
      child: AppGestureDetector(
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
              const DebugMenuIcon(
                icon: Icons.terminal_rounded,
                prominent: true,
              ),
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
                        Flexible(
                          child: Text(
                            'Открыть журнал',
                            style: UITextStyles.semibold13.copyWith(
                              color: UIColors.primary,
                            ),
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
      ),
    );
  }
}
