import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/orbital_rings_widget.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_tilt/flutter_tilt.dart';

import '../../../domain/atom.dart';
import '../../../domain/study_streak.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/margin.dart';
import 'course_controller.dart';
import 'course_path_page.dart';

/// Витрина предстоящего занятия. Объяснения по-прежнему живут в RuleCard
/// внутри урока, а здесь буквы показывают, чем предстоит заниматься.
class CourseLessonPreview extends StatelessWidget {
  const CourseLessonPreview({required this.controller, super.key});
  final CourseController controller;

  static const _tiltConfig = TiltConfig(
    enableGestureTouch: false,
    enableReverse: false,
    leaveCurve: Curves.easeOutCubic,
    leaveDuration: Duration(milliseconds: 1500),
    sensorFactor: 3,
    sensorRevertFactor: .02,
  );

  @override
  Widget build(BuildContext context) {
    final atom = controller.featuredAtom;
    final isNew = controller.nextPlan.value!.newAtoms.isNotEmpty;
    final hasReview =
        controller.nextPlan.value!.reviewAtoms.isNotEmpty ||
        controller.nextPlan.value!.spacedReview.isNotEmpty;
    final label = controller.lessonBadge.isNotEmpty
        ? controller.lessonBadge
        : isNew
        ? hasReview
              ? 'Сегодня: НОВОЕ + ПОВТОРЕНИЕ'
              : 'Сегодня: НОВЫЙ МАТЕРИАЛ'
        : controller.nextPlan.value!.isFocusedReview
        ? 'Сегодня · ЗАКРЕПЛЕНИЕ + НОВОЕ'
        : 'Сегодня · ЗАКРЕПЛЕНИЕ';
    return Tilt(
      tiltConfig: _tiltConfig,
      child: _CourseSurface(
        radius: 28,
        onTap: controller.continueCourse,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            UIColors.coursePreviewGradientStart,
            UIColors.coursePreviewGradientStart,
            UIColors.coursePreviewGradientEnd,
          ],
          stops: const [0, .54615, 1],
        ),
        child: Stack(
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Opacity(opacity: 0, child: _header(label)),
                    _CourseLessonTransformation(
                      atom: atom,
                      source: controller.lessonSource,
                      showBackground: true,
                      showContent: false,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(label),
                _CourseLessonTransformation(
                  atom: atom,
                  source: controller.lessonSource,
                  showBackground: false,
                  showContent: true,
                ),
                _footer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String label) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: UIColors.text,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: UIColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const Margin.horizontal(8),
              Text(
                label,
                style: UITextStyles.monoSemibold11.copyWith(
                  color: UIColors.badgeText1,
                ),
              ),
            ],
          ),
        ),
        const Margin.vertical(12),
        Text(controller.lessonTitle, style: UITextStyles.semibold27),
      ],
    ),
  );

  Widget _footer() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    decoration: BoxDecoration(
      color: UIColors.highlightArea,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.lessonFocus, style: UITextStyles.semibold17),
                const Margin.vertical(4),
                Text(
                  controller.lessonDetail,
                  style: UITextStyles.regular13.copyWith(
                    color: UIColors.secondary2,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_outward_outlined, color: UIColors.secondary2),
        ],
      ),
    ),
  );
}

class _CourseLessonTransformation extends StatelessWidget {
  const _CourseLessonTransformation({
    required this.atom,
    required this.source,
    required this.showBackground,
    required this.showContent,
  });

  final Atom? atom;
  final String source;
  final bool showBackground;
  final bool showContent;

  Widget _content(Widget child) =>
      showContent ? child : Opacity(opacity: 0, child: child);

  @override
  Widget build(BuildContext context) {
    final decorSide = MediaQuery.sizeOf(context).width * .75;
    final showArrow =
        (atom?.kind == AtomKind.syllable && atom?.audioAsset == null) ||
        (atom?.form != null && atom?.form != LetterForm.isolated);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 116,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (source.isNotEmpty) ...[
                Flexible(
                  child: _content(
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _Glyph(
                        source,
                        size: 48,
                        color: UIColors.secondary2,
                      ),
                    ),
                  ),
                ),
                _content(
                  showArrow
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: UIColors.secondary2,
                          ),
                        )
                      : const Margin.horizontal(24),
                ),
              ],
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (showBackground)
                      Positioned.fill(
                        top: 14,
                        child: OverflowBox(
                          alignment: Alignment.center,
                          maxWidth: decorSide,
                          maxHeight: decorSide,
                          child: SizedBox.square(
                            dimension: decorSide,
                            child: OrbitalRingsWidget(
                              color: UIColors.backgroundShapes1,
                              thickness: 1,
                              dashThickness: 1.4,
                            ),
                          ),
                        ),
                      ),
                    if (showContent)
                      Container(
                        width: 116,
                        height: 116,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: UIColors.primary20),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: UIColors.primary,
                            border: Border.all(
                              color: UIColors.borders,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: UIColors.primary20,
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: atom == null
                              ? SvgPicture.asset(
                                  UISVGAssets.bookOutline,
                                  width: 42,
                                  colorFilter: ColorFilter.mode(
                                    UIColors.white,
                                    BlendMode.srcIn,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _Glyph(
                                    atom!.display,
                                    size: 70,
                                    color: UIColors.white,
                                  ),
                                ),
                        ),
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

/// Последние 7 и 30 местных календарных дней. Отметка означает
/// работу с материалом, включая незаконченные занятия.
class CourseActivityWeek extends StatefulWidget {
  const CourseActivityWeek({
    required this.days,
    required this.today,
    this.onDateTap,
    super.key,
  });
  final Set<DateTime> days;
  final DateTime today;
  final ValueChanged<DateTime>? onDateTap;

  @override
  State<CourseActivityWeek> createState() => _CourseActivityWeekState();
}

class _CourseActivityWeekState extends State<CourseActivityWeek> {
  late final _historyDelays = List.generate(
    30,
    (rank) => Duration(milliseconds: rank * 25),
  )..shuffle();
  bool _skipAnimation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _skipAnimation |= MediaQuery.disableAnimationsOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final dates = StudyStreak.weekEndingOn(widget.today);
    return _CourseSurface(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final history = _CourseActivityHistory(
              days: widget.days,
              today: widget.today,
              delays: _historyDelays,
              skipAnimation: _skipAnimation,
            );
            final week = _week(dates);
            if (constraints.maxWidth < 252 ||
                MediaQuery.textScalerOf(context).scale(12) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  week,
                  const Margin.vertical(16),
                  Align(alignment: Alignment.centerRight, child: history),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: week),
                const Margin.horizontal(16),
                history,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _week(List<DateTime> dates) {
    const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: UIColors.primary,
            ),
            const Margin.horizontal(8),
            Expanded(
              child: Text(
                'Последние 7 дней',
                style: UITextStyles.monoSemibold14,
              ),
            ),
          ],
        ),
        const Margin.vertical(16),
        LayoutBuilder(
          builder: (context, constraints) {
            final diameter = ((constraints.maxWidth - 6 * 4) / 7).clamp(
              20.0,
              28.0,
            );
            return SizedBox(
              width: constraints.maxWidth,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 8,
                children: dates.mapIndexed((index, date) {
                  final label = labels[date.weekday - 1];
                  final active = widget.days.contains(date);
                  final current = DateUtils.isSameDay(date, widget.today);
                  final day = Semantics(
                    button: widget.onDateTap != null,
                    label:
                        '$label, ${date.day}.${date.month}${current ? ', сегодня' : ''}, ${active ? 'занимались' : 'без отметки'}',
                    child: _CourseActivityFade(
                      delay: Duration(milliseconds: index * 70),
                      skipAnimation: _skipAnimation,
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Text(
                              label,
                              style: UITextStyles.regular11.copyWith(
                                color: current
                                    ? UIColors.text
                                    : UIColors.secondary2,
                              ),
                            ),
                            const Margin.vertical(4),
                            Container(
                              width: diameter,
                              height: diameter,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? current
                                          ? UIColors.primary
                                          : UIColors.primary20
                                    : current
                                    ? UIColors.primary
                                    : UIColors.backgroundShapes1,
                              ),
                              child: active || current
                                  ? SvgPicture.asset(
                                      UISVGAssets.fire,
                                      height: 16,
                                      colorFilter: ColorFilter.mode(
                                        current
                                            ? UIColors.text
                                            : UIColors.primary,
                                        BlendMode.srcIn,
                                      ),
                                    )
                                  : Text(
                                      '${date.day}',
                                      style: UITextStyles.semibold12.copyWith(
                                        color: current
                                            ? UIColors.text
                                            : UIColors.secondary2,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (widget.onDateTap == null) return day;
                  return AppGestureDetector(
                    onTap: () => widget.onDateTap!(date),
                    child: day,
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CourseActivityHistory extends StatelessWidget {
  const _CourseActivityHistory({
    required this.days,
    required this.today,
    required this.delays,
    required this.skipAnimation,
  });

  final Set<DateTime> days;
  final DateTime today;
  final List<Duration> delays;
  final bool skipAnimation;

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(
      30,
      (index) => DateTime(today.year, today.month, today.day - 29 + index),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          'Последние 30 дней, с ${dates.first.day}.${dates.first.month} по ${dates.last.day}.${dates.last.month}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ExcludeSemantics(
            child: Text(
              '30 дней',
              style: UITextStyles.monoRegular11.copyWith(
                color: UIColors.text.withValues(alpha: .65),
              ),
            ),
          ),
          const Margin.vertical(16),
          SizedBox(
            width: 68,
            child: RepaintBoundary(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: dates.mapIndexed((index, date) {
                  final active = days.contains(date);
                  final current = DateUtils.isSameDay(date, today);
                  return Semantics(
                    label:
                        '${date.day}.${date.month}${current ? ', сегодня' : ''}, ${active ? 'занимались' : 'без отметки'}',
                    child: _CourseActivityFade(
                      delay: delays[index],
                      skipAnimation: skipAnimation,
                      child: SizedBox(
                        width: 6,
                        height: 6,
                        child: Center(
                          child: Container(
                            width: active ? 6 : 4,
                            height: active ? 6 : 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? UIColors.primary
                                  : UIColors.activityInactive,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseActivityFade extends StatelessWidget {
  const _CourseActivityFade({
    required this.child,
    required this.delay,
    required this.skipAnimation,
  });

  final Widget child;
  final Duration delay;
  final bool skipAnimation;

  @override
  Widget build(BuildContext context) => child
      .animate(autoPlay: !skipAnimation, value: skipAnimation ? 1 : null)
      .fadeIn(delay: delay, duration: 450.ms, curve: Curves.easeOutCubic);
}

class CourseOverview extends StatelessWidget {
  const CourseOverview({required this.controller, super.key});
  final CourseController controller;

  void _path() => Get.to(() => CoursePathPage(controller: controller));

  @override
  Widget build(BuildContext context) {
    final upcoming = controller.upcomingTopic.value;
    final nextAtom = upcoming == null
        ? null
        : controller.atomsFor(upcoming).firstOrNull;
    final progress = controller.pathProgress;
    final path = _OverviewTile(
      title: 'Мой путь',
      icon: SvgPicture.asset(
        UISVGAssets.hugeiconsRoad01,
        colorFilter: ColorFilter.mode(UIColors.primary, BlendMode.srcIn),
      ),
      onTap: _path,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Margin.vertical(24),
          Semantics(
            label:
                '${CourseController.stageTitle(progress.stage)}. ${progress.summary}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(
                      value: progress.fraction,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      color: UIColors.primary,
                      backgroundColor: UIColors.backgroundShapes1,
                    ),
                  ),
                  const Margin.horizontal(8),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: '${progress.done}',
                        children: [
                          TextSpan(
                            text: ' / ${progress.total}',
                            style: UITextStyles.regular12.copyWith(
                              color: UIColors.secondary2,
                            ),
                          ),
                        ],
                      ),
                      style: UITextStyles.semibold28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Margin.vertical(12),
          Text(
            !controller.hasStarted && progress.stage == 1
                ? 'Начните с первых букв\nВсе темы курса'
                : '${progress.unit}\n${CourseController.stageTitle(progress.stage)}',
            style: UITextStyles.regular11Relaxed.copyWith(
              color: UIColors.secondary2,
            ),
          ),
        ],
      ),
    );
    final next = _OverviewTile(
      title: upcoming == null ? 'Практика' : 'Далее',
      icon: SvgPicture.asset(
        UISVGAssets.solarRouteLinear,
        colorFilter: ColorFilter.mode(UIColors.primary, BlendMode.srcIn),
      ),
      onTap: upcoming == null
          ? _path
          : () => Get.to(
              () => CourseTopicPage(
                controller: controller,
                topicId: upcoming.topic.id,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Margin.vertical(12),
          if (nextAtom != null)
            ExcludeSemantics(
              child: SizedBox(
                height: 40,
                child: _Glyph(
                  nextAtom.display,
                  size: 34,
                  color: UIColors.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: UIColors.primary,
                size: 28,
              ),
            ),
          const Margin.vertical(4),
          Text(
            upcoming?.topic.title ??
                (controller.allDone ? 'Весь курс знаком' : 'Закрепляем знания'),
            style: UITextStyles.semibold14Relaxed,
          ),
          const Margin.vertical(8),
          Text(
            upcoming == null
                ? 'Возвращайтесь к темам\nи закрепляйте знания'
                : upcoming.canPractice
                ? 'Уже доступно\nМожно перейти'
                : 'После закрепления\nПосмотреть условия',
            style: UITextStyles.regular11Relaxed.copyWith(
              color: UIColors.secondary2,
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [path, const Margin.vertical(12), next],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: path),
              const Margin.horizontal(8),
              Expanded(child: next),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.title,
    required this.onTap,
    required this.child,
    required this.icon,
  });
  final String title;
  final VoidCallback onTap;
  final Widget child;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: _CourseSurface(
      radius: 24,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title, style: UITextStyles.monoSemibold13),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: UIColors.primary10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: icon,
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

class _CourseSurface extends StatelessWidget {
  const _CourseSurface({
    required this.child,
    required this.radius,
    this.gradient,
    this.onTap,
  });
  final Widget child;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppGestureDetector(
    onTap: onTap,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: gradient == null
            ? UIColors.cardBackground.withValues(alpha: .8)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: UIColors.borders),
        boxShadow: [
          BoxShadow(
            color: UIColors.shadows,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: onTap == null ? child : child,
    ),
  );
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.text, {required this.size, required this.color});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: TextDirection.rtl,
    style: UITextStyles.dgFasehRegular(size, height: 1).copyWith(color: color),
  );
}
