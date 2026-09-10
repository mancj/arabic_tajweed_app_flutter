import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'atom_progress_controller.dart';

export 'atom_progress_binding.dart';
export 'atom_progress_controller.dart';

/// Отладочный список атомов с их состоянием. Открывается из [DebugPage].
class AtomProgressPage extends GetView<AtomProgressController> {
  static const routeName = '/debug/atoms';

  const AtomProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Атомы',
      builder: (_, insets) => Obx(() {
        if (controller.loading.value) {
          return const Center(
            child: CircularProgressIndicator(color: UIColors.primary),
          );
        }
        final rows = controller.visible;
        return ListView.builder(
          padding: insets,
          itemCount: rows.length + 1,
          itemBuilder: (_, i) => i == 0
              ? _Summary(controller)
              : _AtomTile(rows[i - 1], controller),
        );
      }),
    );
  }
}

/// Сводка: сколько атомов в каждом состоянии, номер следующей сессии
/// и переключатель свежих.
class _Summary extends StatelessWidget {
  const _Summary(this.controller);

  final AtomProgressController controller;

  @override
  Widget build(BuildContext context) {
    final counts = controller.counts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in counts.entries)
                _Badge('${e.key.name} ${e.value}', _stateColor(e.key)),
            ],
          ),
          const Margin.vertical(8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Следующая сессия: ${controller.nextSession.value}',
                  style: UITextStyles.hint,
                ),
              ),
              const Text('Скрыть fresh', style: UITextStyles.hint),
              Switch(
                value: controller.hideFresh.value,
                activeThumbColor: UIColors.primary,
                onChanged: (v) => controller.hideFresh.value = v,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtomTile extends StatelessWidget {
  const _AtomTile(this.row, this.controller);

  final AtomRow row;
  final AtomProgressController controller;

  @override
  Widget build(BuildContext context) {
    final p = row.progress;
    final atom = row.atom;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: UIColors.cardBackground,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              atom.display,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: UITextStyles.fontScheherazadeNew,
                fontSize: 16,
                color: UIColors.text,
              ),
            ),
          ),
          const Margin.horizontal(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(atom.id, style: UITextStyles.semibold17),
                    ),
                    if (p.weak) const _Badge('weak', UIColors.secondary1),
                    if (controller.isDeferred(p))
                      const _Badge('deferred', UIColors.secondary1),
                    _Badge(p.state.name, _stateColor(p.state)),
                  ],
                ),
                const Margin.vertical(4),
                Text(_details(p), style: UITextStyles.hint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Всё, что решает судьбу атома в свёртке, одной строкой.
  String _details(AtomProgress p) {
    final modes = p.modesInStreak.map((m) => m.name).join(', ');
    return [
      'серия ${p.cleanStreak}${modes.isEmpty ? '' : ' [$modes]'}',
      'ошибок ${p.totalErrors}, сессий с ошибкой ${p.failedSessions.length}',
      'откладываний ${p.deferCount}'
          '${p.deferredAtSession == null ? '' : ' (с #${p.deferredAtSession})'}',
      'подтверждений ${p.confirmations}'
          '${p.knownAt == null ? '' : ', known ${_date(p.knownAt!)}'}',
      'активный успех: ${p.hadActiveSuccess ? 'да' : 'нет'}',
      'видели в #${p.lastSeenSession ?? '—'}',
    ].join('\n');
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: UITextStyles.regular12.copyWith(color: color)),
    );
  }
}

Color _stateColor(AtomState state) => switch (state) {
  AtomState.fresh => UIColors.secondary2,
  AtomState.introduced => UIColors.secondary1,
  AtomState.learning => UIColors.primary,
  AtomState.known => UIColors.secondary1,
  AtomState.mastered => UIColors.primary,
};
