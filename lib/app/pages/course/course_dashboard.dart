import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/atom.dart';
import '../../resources/ui_resources.dart';
import 'course_controller.dart';
import 'course_path_page.dart';

/// Витрина предстоящего занятия. Объяснения по-прежнему живут в RuleCard
/// внутри урока, а здесь буквы показывают, чем предстоит заниматься.
class CourseLessonPreview extends StatelessWidget {
  const CourseLessonPreview({required this.controller, super.key});
  final CourseController controller;

  @override
  Widget build(BuildContext context) {
    final atom = controller.featuredAtom;
    final isNew = controller.nextPlan.value!.newAtoms.isNotEmpty;
    final hasReview =
        controller.nextPlan.value!.reviewAtoms.isNotEmpty ||
        controller.nextPlan.value!.spacedReview.isNotEmpty;
    return _CourseSurface(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: UIColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        isNew
                            ? hasReview
                                  ? 'СЕГОДНЯ · НОВОЕ И ПОВТОРЕНИЕ'
                                  : 'СЕГОДНЯ · НОВЫЙ МАТЕРИАЛ'
                            : 'СЕГОДНЯ · ЗАКРЕПЛЕНИЕ',
                        style: UITextStyles.regular12.copyWith(
                          color: UIColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  controller.lessonTitle,
                  style: UITextStyles.pageTitleSemibold.copyWith(
                    fontSize: 27,
                    height: 1.12,
                    letterSpacing: -.6,
                    fontFamilyFallback: const [
                      UITextStyles.fontScheherazadeNew,
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 116,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (controller.lessonSource.isNotEmpty) ...[
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Glyph(
                            controller.lessonSource,
                            size: 48,
                            color: UIColors.secondary2,
                          ),
                        ),
                      ),
                      if (atom?.kind == AtomKind.syllable ||
                          (atom?.form != null &&
                              atom?.form != LetterForm.isolated))
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: UIColors.secondary2,
                          ),
                        )
                      else
                        const SizedBox(width: 24),
                    ],
                    Container(
                      width: 116,
                      height: 116,
                      padding: const EdgeInsets.all(7),
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
                          border: Border.all(color: UIColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: UIColors.primary20,
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: atom == null
                            ? const Icon(
                                Icons.auto_stories_outlined,
                                color: UIColors.highlightArea,
                                size: 42,
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _Glyph(
                                  atom.display,
                                  size: 70,
                                  color: UIColors.highlightArea,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: UIColors.highlightArea,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.lessonFocus,
                    style: UITextStyles.regular14.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.lessonDetail,
                    style: UITextStyles.hint.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.mapIndexed((index, label) {
        final date = DateTime(monday.year, monday.month, monday.day + index);
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
                  style: UITextStyles.hint.copyWith(
                    fontSize: 11,
                    color: current ? UIColors.text : UIColors.secondary2,
                  ),
                ),
                const SizedBox(height: 7),
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
                          size: 18,
                          color: current
                              ? UIColors.highlightArea
                              : UIColors.primary,
                        )
                      : Text(
                          '${date.day}',
                          style: UITextStyles.regular12.copyWith(
                            color: current
                                ? UIColors.highlightArea
                                : UIColors.secondary2,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
      onTap: _path,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
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
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: '${controller.knownLetters}',
                        children: [
                          TextSpan(
                            text: ' / ${controller.totalLetters}',
                            style: UITextStyles.hint,
                          ),
                        ],
                      ),
                      style: UITextStyles.pageTitleSemibold.copyWith(
                        fontSize: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            controller.hasStarted
                ? 'букв освоено\nВсе темы и знания'
                : 'Начните с первых букв\nВсе темы курса',
            style: UITextStyles.hint.copyWith(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
    final next = _OverviewTile(
      title: upcoming == null ? 'Практика' : 'Далее',
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
          const SizedBox(height: 8),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: UIColors.primary,
                size: 28,
              ),
            ),
          const SizedBox(height: 5),
          Text(
            upcoming?.topic.title ??
                (controller.allDone ? 'Весь курс знаком' : 'Закрепляем знания'),
            style: UITextStyles.regular14.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            upcoming == null
                ? 'Возвращайтесь к темам\nи закрепляйте знания'
                : upcoming.canPractice
                ? 'Уже доступно\nМожно перейти'
                : 'После закрепления\nПосмотреть условия',
            style: UITextStyles.hint.copyWith(fontSize: 11, height: 1.5),
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
            children: [path, const SizedBox(height: 12), next],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: path),
              const SizedBox(width: 12),
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
  });
  final String title;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: _CourseSurface(
      radius: 23,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: UITextStyles.regular14.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: UIColors.secondary2,
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
  const _CourseSurface({required this.child, required this.radius, this.onTap});
  final Widget child;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: UIColors.text.withValues(alpha: .04),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Material(
      color: UIColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: UIColors.highlightArea),
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
    style: TextStyle(
      fontFamily: UITextStyles.fontScheherazadeNew,
      fontSize: size,
      height: 1,
      color: color,
    ),
  );
}
