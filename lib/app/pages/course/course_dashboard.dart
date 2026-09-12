import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter_tilt/flutter_tilt.dart';

import '../../../domain/atom.dart';
import '../../resources/ui_resources.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/animated_background_shapes.dart';
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
    final label = isNew
        ? hasReview
              ? 'Сегодня: НОВОЕ И ПОВТОРЕНИЕ'
              : 'Сегодня: НОВЫЙ МАТЕРИАЛ'
        : controller.nextPlan.value!.isFocusedReview
        ? 'Сегодня · ЗАКРЕПЛЕНИЕ И НОВОЕ'
        : 'Сегодня · ЗАКРЕПЛЕНИЕ';
    return Tilt(
      tiltConfig: _tiltConfig,
      child: _CourseSurface(
        radius: 28,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            UIColors.coursePreviewGradientStart,
            UIColors.coursePreviewGradientStart,
            UIColors.coursePreviewGradientEnd,
          ],
          stops: [0, .54615, 1],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(controller.lessonFocus, style: UITextStyles.semibold17),
          const Margin.vertical(4),
          Text(
            controller.lessonDetail,
            style: UITextStyles.regular13.copyWith(color: UIColors.secondary2),
          ),
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
    final decorSide = MediaQuery.sizeOf(context).width;
    final showArrow =
        atom?.kind == AtomKind.syllable ||
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
                        child: OverflowBox(
                          alignment: Alignment.center,
                          maxWidth: decorSide,
                          maxHeight: decorSide,
                          child: SizedBox.square(
                            dimension: decorSide,
                            child: const AnimatedBackgroundShapes(),
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
                              color: UIColors.cardBackground,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: UIColors.primary20,
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: atom == null
                              ? Icon(
                                  Icons.auto_stories_outlined,
                                  color: UIColors.highlightArea,
                                  size: 42,
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _Glyph(
                                    atom!.display,
                                    size: 70,
                                    color: UIColors.highlightArea,
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

/// Понедельник–воскресенье по местному календарю. Отметка означает работу
/// в этот день, а не завершение урока или обещанную серию без пропусков.
class CourseActivityWeek extends StatelessWidget {
  const CourseActivityWeek({
    required this.days,
    required this.today,
    super.key,
  });
  final Set<DateTime> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return _CourseSurface(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: UIColors.primary,
                ),
                const Margin.horizontal(8),
                Text('Эта неделя', style: UITextStyles.monoSemibold14),
                const Spacer(),
                Text(
                  'Ваш ритм',
                  style: UITextStyles.monoRegular12.copyWith(
                    color: UIColors.secondary2,
                  ),
                ),
              ],
            ),
            const Margin.vertical(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels.mapIndexed((index, label) {
                final date = DateTime(
                  monday.year,
                  monday.month,
                  monday.day + index,
                );
                final active = days.contains(date);
                final current = DateUtils.isSameDay(date, today);
                return Semantics(
                  label:
                      '$label, ${date.day}.${date.month}${current ? ', сегодня' : ''}, ${active ? 'занимались' : 'без отметки'}',
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
                        const Margin.vertical(8),
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: current
                                ? UIColors.primary
                                : active
                                ? UIColors.primary20
                                : UIColors.backgroundShapes1,
                          ),
                          child: active
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: current
                                      ? UIColors.badgeText1
                                      : UIColors.primary,
                                )
                              : Text(
                                  '${date.day}',
                                  style: UITextStyles.semibold12.copyWith(
                                    color: current
                                        ? UIColors.primaryButtonText
                                        : UIColors.secondary2,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
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
    final progress = controller.totalLetters == 0
        ? 0.0
        : controller.knownLetters / controller.totalLetters;
    final path = _OverviewTile(
      title: 'Мой путь',
      icon: SvgPicture.asset(
        UISVGAssets.solarRouteLinear,
        colorFilter: ColorFilter.mode(UIColors.primary, BlendMode.srcIn),
      ),
      onTap: _path,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Margin.vertical(24),
          Semantics(
            label:
                'Освоено букв: ${controller.knownLetters} из ${controller.totalLetters}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(
                      value: progress,
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
                        text: '${controller.knownLetters}',
                        children: [
                          TextSpan(
                            text: ' / ${controller.totalLetters}',
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
            controller.hasStarted
                ? 'букв освоено\nВсе темы и знания'
                : 'Начните с первых букв\nВсе темы курса',
            style: UITextStyles.regular11Relaxed.copyWith(
              color: UIColors.secondary2,
            ),
          ),
        ],
      ),
    );
    final next = _OverviewTile(
      title: upcoming == null ? 'Практика' : 'Далее',
      icon: Icon(
        upcoming == null
            ? Icons.auto_awesome_rounded
            : Icons.arrow_outward_rounded,
        color: UIColors.primary,
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: gradient == null ? UIColors.cardBackground : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: UIColors.shadows,
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Material(
      color: gradient == null ? UIColors.cardBackground : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: UIColors.highlightArea),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
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
