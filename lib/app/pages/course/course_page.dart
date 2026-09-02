import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/pages/debug/debug_page.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';

import 'course_controller.dart';

export 'course_binding.dart';
export 'course_controller.dart';

/// Главный экран курса.
///
/// Показывает не список уроков, а список понятий: уроки собирает
/// планировщик, и что будет через три захода, заранее неизвестно.
/// Понятий же на весь курс полтора десятка, они авторские и стабильные.
class CoursePage extends GetView<CourseController> {
  static const routeName = '/course';

  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Курс',
      showBackButton: false,
      bottomBar: Obx(
        () => NextButton(
          title: controller.continueLabel,
          subtitle: _continueSubtitle(controller),
          onTap: controller.continueCourse,
        ),
      ),
      builder: (context, insets) => Obx(() {
        if (controller.loading.value) {
          return const Center(
            child: CircularProgressIndicator(color: UIColors.primary),
          );
        }
        // Пустой список без объяснения выглядит как рабочий экран, хотя
        // означает, что контент не загрузился. Показываем причину.
        if (controller.statuses.isEmpty) {
          return Padding(
            padding: insets,
            child: _LoadFailure(error: controller.loadError.value),
          );
        }

        return SingleChildScrollView(
          padding: insets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StreakCard(),
              // Меню отладки достижимо только из debug-сборки: сплэш ведёт
              // сразу на курс, а сбрасывать прогресс при проверке контента
              // приходится постоянно.
              if (kDebugMode) ...[
                const Margin.vertical(12),
                const _DebugLink(),
              ],
              const Margin.vertical(24),
              if (controller.unfinished.isNotEmpty) ...[
                const Margin.vertical(12),
                const _UnfinishedBanner(),
              ],
              const Margin.vertical(12),
              for (final entry in controller.byStage.entries) ...[
                _StageHeader(stage: entry.key),
                const Margin.vertical(10),
                for (final status in entry.value) ...[
                  _TopicTile(
                    status: status,
                    onTap: status.canPractice
                        ? () => controller.open(status)
                        : null,
                  ),
                  const Margin.vertical(8),
                ],
                const Margin.vertical(16),
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// Подпись под кнопкой: куда ведёт и, если впереди замок, чего не хватает
/// для его снятия.
String? _continueSubtitle(CourseController controller) {
  final locked = controller.nextLocked;
  final target = controller.continueTarget;

  // Если впереди замок, подпись объясняет, ради чего повторять.
  if (locked != null && locked.hint.isNotEmpty && (target?.isDone ?? true)) {
    return '${locked.topic.title}: ${locked.hint}';
  }
  if (target == null) {
    return controller.statuses.isEmpty ? null : 'То, что успело подзабыться';
  }
  return target.topic.title;
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 32,
          color: UIColors.secondary2,
        ),
        const Margin.vertical(12),
        const Text('Курс не загрузился', style: UITextStyles.semiboldText),
        const Margin.vertical(8),
        Text(
          error ?? 'В контенте нет ни одного урока — проверьте assets.',
          style: UITextStyles.hint,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StreakCard extends GetView<CourseController> {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: SquircleBorders.squircleBorder(
          color: UIColors.cardBackground,
          borderRadius: 24,
        ),
        child: Row(
          children: [
            Text(
              '${controller.streakDays.value}',
              style: UITextStyles.pageTitleSemibold,
            ),
            const Margin.horizontal(12),
            const Expanded(
              // TODO(streak): считать по журналу заходов, см. SPEC.md §9.
              child: Text(
                'дней подряд · счётчик ещё не считается',
                style: UITextStyles.regularText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugLink extends StatelessWidget {
  const _DebugLink();

  @override
  Widget build(BuildContext context) => AppGestureDetector(
    onTap: () => Get.toNamed(DebugPage.routeName),
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text('Меню отладки', style: UITextStyles.hint),
    ),
  );
}

/// Напоминание о брошенных уроках. Не долг и не ошибка: буквы оттуда всё
/// равно всплывают в повторениях. Просто способ вернуться, если захочется.
class _UnfinishedBanner extends GetView<CourseController> {
  const _UnfinishedBanner();

  @override
  Widget build(BuildContext context) {
    final count = controller.unfinished.length;
    return AppGestureDetector(
      onTap: () => controller.open(controller.unfinished.first),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: SquircleBorders.squircleBorder(
          color: UIColors.iceBlue,
          borderRadius: 16,
        ),
        child: Row(
          children: [
            const Icon(Icons.pause_rounded, size: 18, color: UIColors.tealDark),
            const Margin.horizontal(10),
            Expanded(
              child: Text(
                count == 1
                    ? 'Один урок остался незакрытым'
                    : 'Незакрытых уроков: $count',
                style: UITextStyles.regularText,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: UIColors.tealDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage});

  final int stage;

  /// Названия этапов из SPEC.md §7. Этапы 5–6 ещё не проработаны.
  static const _titles = {
    1: 'Этап 1 · Буквы',
    2: 'Этап 2 · Соединение',
    3: 'Этап 3 · Огласовки',
    4: 'Этап 4 · Знаки чтения',
    5: 'Этап 5 · Чтение слов',
    6: 'Этап 6 · Правила письма',
  };

  @override
  Widget build(BuildContext context) =>
      Text(_titles[stage] ?? 'Этап $stage', style: UITextStyles.hint);
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.status, this.onTap});

  final TopicStatus status;

  /// null у закрытых вех: тренировать там нечего, атомы не введены.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = status.state == TopicState.locked;

    return AppGestureDetector(onTap: onTap, child: _body(locked));
  }

  Widget _body(bool locked) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: SquircleBorders.squircleBorder(
        color: switch (status.state) {
          TopicState.current => UIColors.primary20,
          TopicState.locked => UIColors.itemBackground,
          _ => UIColors.cardBackground,
        },
        borderRadius: 20,
      ),
      child: Row(
        children: [
          _StateMark(state: status.state),
          const Margin.horizontal(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.topic.title,
                  style: locked
                      ? UITextStyles.regularText
                      : UITextStyles.semiboldText,
                ),
                // Замок объясняет себя: это ребро графа словами, а не
                // абстрактное «скоро откроется».
                if (locked && status.hint.isNotEmpty) ...[
                  const Margin.vertical(4),
                  Text(status.hint, style: UITextStyles.hint),
                ],
              ],
            ),
          ),
          // Освоенность показываем только у незакрытых уроков: у закрытого
          // это число уже ничего не решает и выглядит как «не доделал».
          if (status.showsMastery && status.hasCounter) ...[
            const Margin.horizontal(12),
            _Counter(status: status),
          ] else if (!locked) ...[
            const Margin.horizontal(12),
            Text(_labelOf(status.state), style: UITextStyles.hint),
          ],
        ],
      ),
    );
  }
}

class _StateMark extends StatelessWidget {
  const _StateMark({required this.state});

  final TopicState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      TopicState.done => (Icons.check_rounded, UIColors.teal),
      // Сдан тестом — не галочка: урок не проходили, атомы подтверждены
      // слабее обычного, и честнее показать это отдельным знаком.
      TopicState.passedByTest => (Icons.verified_outlined, UIColors.secondary3),
      TopicState.current => (Icons.play_arrow_rounded, UIColors.primary),
      TopicState.unfinished => (Icons.pause_rounded, UIColors.coral),
      TopicState.available => (Icons.play_arrow_outlined, UIColors.secondary2),
      TopicState.locked => (Icons.lock_outline_rounded, UIColors.secondary2),
    };
    return Icon(icon, color: color, size: 22);
  }
}

String _labelOf(TopicState state) => switch (state) {
  TopicState.done => 'пройден',
  TopicState.passedByTest => 'зачтён тестом',
  TopicState.available => '',
  _ => '',
};

class _Counter extends StatelessWidget {
  const _Counter({required this.status});

  final TopicStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${status.done} / ${status.total}', style: UITextStyles.hint),
        const Margin.vertical(6),
        SizedBox(
          width: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: status.progress,
              minHeight: 5,
              backgroundColor: UIColors.secondary1,
              valueColor: const AlwaysStoppedAnimation(UIColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
