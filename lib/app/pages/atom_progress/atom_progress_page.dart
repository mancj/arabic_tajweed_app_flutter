import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'atom_progress_controller.dart';

export 'atom_progress_binding.dart';
export 'atom_progress_controller.dart';

/// Отладочный список атомов с их состоянием. Открывается из меню отладки.
class AtomProgressPage extends GetView<AtomProgressController> {
  static const routeName = '/debug/atoms';

  const AtomProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Атомы',
      builder: (_, insets) => Obx(() {
        if (controller.loading.value) {
          return Center(
            child: CircularProgressIndicator(color: UIColors.primary),
          );
        }
        final rows = controller.visible;
        return ListView.builder(
          padding: insets,
          itemCount: rows.isEmpty ? 2 : rows.length + 1,
          itemBuilder: (_, index) {
            if (index == 0) {
              return _Summary(controller, visibleCount: rows.length);
            }
            if (rows.isEmpty) return const _EmptyState();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AtomTile(rows[index - 1], controller),
            );
          },
        );
      }),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.controller, {required this.visibleCount});

  final AtomProgressController controller;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final counts = controller.counts;
    final total = controller.rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'СОСТОЯНИЯ КУРСА',
                style: UITextStyles.monoSemibold11.copyWith(
                  color: UIColors.primary,
                ),
              ),
              const Margin.vertical(8),
              Text('Прогресс атомов', style: UITextStyles.semibold28),
              const Margin.vertical(8),
              Text(
                'Свёртка журнала обучения по каждому элементу.',
                style: UITextStyles.regular15.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
            ],
          ),
        ),
        const Margin.vertical(24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UIColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$total', style: UITextStyles.semibold32),
                  const Margin.horizontal(8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'атомов всего',
                        style: UITextStyles.regular13.copyWith(
                          color: UIColors.secondary2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: UIColors.primary10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'СЕССИЯ #${controller.nextSession.value}',
                      style: UITextStyles.monoSemibold11.copyWith(
                        color: UIColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Margin.vertical(16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: ColoredBox(
                    color: UIColors.pageBackground,
                    child: Row(
                      children: [
                        for (final state in AtomState.values)
                          if (counts[state]! > 0)
                            Expanded(
                              flex: counts[state]!,
                              child: SizedBox(
                                height: 8,
                                child: ColoredBox(color: _stateColor(state)),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const Margin.vertical(16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final state in AtomState.values)
                    _StateCount(state: state, count: counts[state]!),
                ],
              ),
            ],
          ),
        ),
        const Margin.vertical(12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: UIColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: UIColors.primary,
              ),
              const Margin.horizontal(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Скрыть fresh', style: UITextStyles.semibold15),
                    const Margin.vertical(4),
                    Text(
                      'Показать только атомы с историей',
                      style: UITextStyles.regular12.copyWith(
                        color: UIColors.secondary2,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.hideFresh.value,
                activeThumbColor: UIColors.primary,
                onChanged: (value) => controller.hideFresh.value = value,
              ),
            ],
          ),
        ),
        const Margin.vertical(32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Список атомов', style: UITextStyles.semibold17),
              ),
              Text(
                '$visibleCount показано',
                style: UITextStyles.monoRegular11.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
            ],
          ),
        ),
        const Margin.vertical(12),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UIColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: UIColors.secondary2),
          const Margin.vertical(12),
          Text('Здесь пока пусто', style: UITextStyles.semibold17),
          const Margin.vertical(4),
          Text(
            'Отключите «Скрыть fresh», чтобы увидеть все атомы.',
            textAlign: TextAlign.center,
            style: UITextStyles.regular13.copyWith(color: UIColors.secondary2),
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
    final atom = row.atom;
    final progress = row.progress;
    final isConcept = atom.kind == AtomKind.concept;
    final modes = progress.modesInStreak.map((mode) => mode.name).join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UIColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: UIColors.primary10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isConcept
                    ? Icon(Icons.lightbulb_outline, color: UIColors.primary)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          atom.display,
                          maxLines: 1,
                          style: UITextStyles.arabicRegular38Compact,
                        ),
                      ),
              ),
              const Margin.horizontal(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConcept
                          ? atom.display
                          : atom.label.isEmpty
                          ? atom.id
                          : atom.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: UITextStyles.semibold16,
                    ),
                    const Margin.vertical(4),
                    Text(
                      atom.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UITextStyles.monoRegular11.copyWith(
                        color: UIColors.secondary2,
                      ),
                    ),
                  ],
                ),
              ),
              const Margin.horizontal(8),
              _StateBadge(progress.state),
            ],
          ),
          if (progress.weak || controller.isDeferred(progress)) ...[
            const Margin.vertical(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (progress.weak) const _FlagBadge('weak'),
                if (controller.isDeferred(progress))
                  const _FlagBadge('deferred'),
              ],
            ),
          ],
          const Margin.vertical(16),
          Container(height: 1, color: UIColors.pageBackground),
          const Margin.vertical(16),
          Row(
            children: [
              _Metric(label: 'СЕРИЯ', value: '${progress.cleanStreak}'),
              _Metric(label: 'ОШИБКИ', value: '${progress.totalErrors}'),
              _Metric(label: 'ПОДТВЕРЖД.', value: '${progress.confirmations}'),
            ],
          ),
          const Margin.vertical(16),
          _DetailLine(
            label: 'Режимы серии',
            value: modes.isEmpty ? '—' : modes,
          ),
          const Margin.vertical(8),
          _DetailLine(
            label: 'Сессий с ошибкой',
            value: '${progress.failedSessions.length}',
          ),
          const Margin.vertical(8),
          _DetailLine(
            label: 'Откладываний',
            value:
                '${progress.deferCount}'
                '${progress.deferredAtSession == null ? '' : ' · с #${progress.deferredAtSession}'}',
          ),
          const Margin.vertical(8),
          _DetailLine(
            label: 'Активный успех',
            value: progress.hadActiveSuccess ? 'да' : 'нет',
          ),
          const Margin.vertical(8),
          _DetailLine(
            label: 'Последний показ',
            value: progress.lastSeenSession == null
                ? '—'
                : '#${progress.lastSeenSession}',
          ),
          if (progress.knownAt != null) ...[
            const Margin.vertical(8),
            _DetailLine(
              label: 'В состоянии known с',
              value: _date(progress.knownAt!),
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: UITextStyles.semibold20),
          const Margin.vertical(4),
          Text(
            label,
            style: UITextStyles.monoRegular11.copyWith(
              color: UIColors.secondary2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label  ',
          style: UITextStyles.regular12.copyWith(color: UIColors.secondary2),
        ),
        Expanded(child: Text(value, style: UITextStyles.regular12)),
      ],
    );
  }
}

class _StateCount extends StatelessWidget {
  const _StateCount({required this.state, required this.count});

  final AtomState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _stateColor(state),
            shape: BoxShape.circle,
          ),
        ),
        const Margin.horizontal(4),
        Text(
          '${state.name} $count',
          style: UITextStyles.monoRegular11.copyWith(
            color: UIColors.secondary2,
          ),
        ),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge(this.state);

  final AtomState state;

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state.name,
        style: UITextStyles.monoRegular11.copyWith(
          color: state == AtomState.fresh ? UIColors.secondary2 : color,
        ),
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: UIColors.pageBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: UITextStyles.monoRegular11.copyWith(color: UIColors.secondary2),
      ),
    );
  }
}

Color _stateColor(AtomState state) => switch (state) {
  AtomState.fresh => UIColors.ornamentStroke,
  AtomState.introduced => UIColors.secondary1,
  AtomState.learning => UIColors.primary70,
  AtomState.known => UIColors.success,
  AtomState.mastered => UIColors.primary,
};
