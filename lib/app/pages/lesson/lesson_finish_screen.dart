import 'dart:async';

import 'package:arabic_tajweed_app/app/widgets/ui_kit/starfield_widget.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tilt/flutter_tilt.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/animated_background_shapes.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

import 'lesson_controller.dart';

Duration _delay(Duration delay) => 100.ms + delay;

/// Итог урока или повторения со своей шапкой и действием закрытия.
class LessonFinishScreen extends StatelessWidget {
  const LessonFinishScreen({required this.controller, super.key});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final introduced = controller.sessionIntroduced;
    final isReview = controller.isReviewOnly;
    final exerciseCount = controller.completedExerciseCount;

    return AppScaffold(
      key: kDebugMode ? UniqueKey() : null,
      title: isReview ? 'Повторение' : 'Урок',
      bottomBar: NextButton(title: 'Закрыть', onTap: Get.back).animate().fadeIn(
        duration: 200.ms,
        delay: _delay(1000.ms),
        curve: Curves.easeInOut,
      ),
      builder: (context, insets) => Stack(
        fit: StackFit.expand,
        children: [
          _FinishHaptics(
            delays: [
              _delay(0.ms),
              if (exerciseCount > 0) ...[
                _delay(_delay(0.ms)),
                _delay(_delay(200.ms)),
              ],
            ],
          ),
          _TimedStarfield(
            duration: 2000.ms,
            child: StarfieldWidget(
              minRadius: .5,
              maxRadius: 1,
              speed: .3,
              particleCount: 100,
              color: UIColors.primary70,
              particleLifetime: 2000.ms,
            ),
          ),
          SingleChildScrollView(
            padding: insets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Margin.vertical(24),
                _FinishHero(
                      isReview: isReview,
                      hasNewMaterial: introduced.isNotEmpty,
                    )
                    .animate()
                    .fadeIn(
                      duration: 1000.ms,
                      delay: _delay(0.ms),
                      curve: Curves.easeInOutBack,
                    )
                    .slideY(begin: .1),
                if (exerciseCount > 0) ...[
                  const Margin.vertical(16),
                  _FinishStats(
                    exerciseCount: exerciseCount,
                    firstTryCount: controller.firstTryCorrectCount,
                  ),
                ],
                const Margin.vertical(16),
                if (introduced.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Сегодня разобрали',
                          style: UITextStyles.semibold20,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: UIColors.primary10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${introduced.length}',
                          style: UITextStyles.monoSemibold14.copyWith(
                            color: UIColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(
                    duration: 600.ms,
                    delay: _delay(1000.ms),
                    curve: Curves.easeInOut,
                  ),
                  const Margin.vertical(12),
                  _LearnedGrid(atoms: introduced),
                ] else
                  const _FinishReviewNote(),
                if (kDebugMode && controller.planReason.isNotEmpty) ...[
                  const Margin.vertical(16),
                  Text(
                    controller.planReason,
                    style: UITextStyles.monoMedium12.copyWith(
                      color: UIColors.secondary2,
                      fontFamilyFallback: [UITextStyles.fontDGFaseh],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishHaptics extends StatefulWidget {
  const _FinishHaptics({required this.delays});

  final List<Duration> delays;

  @override
  State<_FinishHaptics> createState() => _FinishHapticsState();
}

class _FinishHapticsState extends State<_FinishHaptics> {
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    for (final delay in widget.delays) {
      _timers.add(Timer(delay, AppHaptics.light));
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TimedStarfield extends StatefulWidget {
  const _TimedStarfield({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_TimedStarfield> createState() => _TimedStarfieldState();
}

class _TimedStarfieldState extends State<_TimedStarfield> {
  Timer? _timer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _scheduleRemoval();
  }

  @override
  void didUpdateWidget(_TimedStarfield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _isVisible = true;
      _scheduleRemoval();
    }
  }

  void _scheduleRemoval() {
    _timer?.cancel();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _isVisible ? widget.child : const SizedBox.shrink();
}

class _FinishHero extends StatelessWidget {
  const _FinishHero({required this.isReview, required this.hasNewMaterial});

  static const _tiltConfig = TiltConfig(
    enableGestureTouch: false,
    enableReverse: false,
    leaveCurve: Curves.easeOutCubic,
    leaveDuration: Duration(milliseconds: 1500),
    sensorFactor: 3,
    sensorRevertFactor: .02,
  );

  final bool isReview;
  final bool hasNewMaterial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 28,
        borderSide: BorderSide(color: UIColors.borders),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Tilt(
            tiltConfig: _tiltConfig,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      maxWidth: MediaQuery.sizeOf(context).width,
                      maxHeight: MediaQuery.sizeOf(context).width,
                      child: SizedBox.square(
                        dimension: MediaQuery.sizeOf(context).width,
                        child: const AnimatedBackgroundShapes(),
                      ),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: UIColors.primary10,
                      border: Border.all(color: UIColors.primary30),
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: UIColors.primary,
                      ),
                      child: Icon(
                        isReview ? Icons.refresh_rounded : Icons.check_rounded,
                        size: 30,
                        color: UIColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Margin.vertical(24),
          Text(
            'Занятие завершено',
            style: UITextStyles.monoSemibold13.copyWith(
              color: UIColors.primary,
            ),
          ),
          const Margin.vertical(8),
          Text(
            isReview ? 'Повторение пройдено' : 'Урок пройден',
            style: UITextStyles.semibold29,
            textAlign: TextAlign.center,
          ),
          const Margin.vertical(8),
          Text(
            hasNewMaterial
                ? 'Вы познакомились с новым материалом. В следующих занятиях вернёмся к нему ещё раз.'
                : 'Вы завершили практику знакомого материала. Возвращайтесь к нему, чтобы закреплять знания.',
            style: UITextStyles.regular15.copyWith(color: UIColors.secondary1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FinishStats extends StatelessWidget {
  const _FinishStats({
    required this.exerciseCount,
    required this.firstTryCount,
  });

  final int exerciseCount;
  final int firstTryCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _FinishStat(
          value: exerciseCount,
          label: 'Выполнено заданий',
          animationDelay: _delay(0.ms),
          animationIndex: 0,
        ),
      ),
      const Margin.horizontal(8),
      Expanded(
        child: _FinishStat(
          value: firstTryCount,
          label: 'С первого раза',
          animationDelay: _delay(200.ms),
          animationIndex: 1,
        ),
      ),
    ],
  );
}

class _FinishStat extends StatelessWidget {
  const _FinishStat({
    required this.value,
    required this.label,
    required this.animationDelay,
    required this.animationIndex,
  });

  final int value;
  final String label;
  final Duration animationDelay;
  final int animationIndex;

  @override
  Widget build(BuildContext context) =>
      Container(
            padding: const EdgeInsets.all(16),
            decoration: SquircleBorders.squircleBorder(
              color: UIColors.cardBackground,
              borderRadius: 20,
              borderSide: BorderSide(color: UIColors.borders),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: UITextStyles.semibold27),
                const Margin.vertical(4),
                Text(
                  label,
                  style: UITextStyles.monoMedium12.copyWith(
                    color: UIColors.secondary2,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(
            duration: 500.ms,
            delay: _delay(animationDelay),
            curve: Curves.easeInOut,
          )
          .slideY(begin: .2)
          .then()
          .shimmer(
            duration: 2000.ms,
            color: UIColors.white.withValues(alpha: 0.1),
            delay: _delay(animationDelay) * (animationIndex / 2),
          );
}

class _FinishReviewNote extends StatelessWidget {
  const _FinishReviewNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: SquircleBorders.squircleBorder(
      color: UIColors.cardBackground,
      borderRadius: 24,
      borderSide: BorderSide(color: UIColors.borders),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          UISVGAssets.bookFilled,
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(UIColors.primary, BlendMode.srcIn),
        ),
        const Margin.horizontal(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сегодня повторили', style: UITextStyles.semibold17),
              const Margin.vertical(4),
              Text(
                'Новых элементов в этом занятии не было. Продолжайте практику, чтобы увереннее узнавать знакомые буквы и формы.',
                style: UITextStyles.regular15.copyWith(
                  color: UIColors.secondary2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LearnedGrid extends StatelessWidget {
  const _LearnedGrid({required this.atoms});

  final List<Atom> atoms;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? 1
          : 2;
      final rows = atoms.slices(columns).toList();

      return Column(
        children: [
          for (final (rowIndex, row) in rows.indexed) ...[
            if (rowIndex > 0) const Margin.vertical(8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, atom) in row.indexed) ...[
                    if (index > 0) const Margin.horizontal(8),
                    Expanded(child: _LearnedTile(atom: atom))
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: _delay(
                            (700 + (300 * rowIndex + 100 * index)).ms,
                          ),
                        )
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 1000.ms,
                          curve: Curves.easeInOutBack,
                        ),
                  ],
                  if (row.length < columns) ...[
                    const Margin.horizontal(8),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _LearnedTile extends StatelessWidget {
  const _LearnedTile({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    final isConcept = atom.kind == AtomKind.concept;
    final category = switch (atom.kind) {
      AtomKind.letterForm => 'Буква и её форма',
      AtomKind.concept => 'Правило',
      AtomKind.haraka || AtomKind.sign => 'Знак',
      AtomKind.syllable => 'Слог',
      AtomKind.word => 'Слово',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 20,
        borderSide: BorderSide(color: UIColors.borders),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: UITextStyles.monoMedium12.copyWith(
              color: UIColors.secondary2,
            ),
          ),
          const Margin.vertical(8),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: SquircleBorders.squircleBorder(
              color: UIColors.primary10,
              borderSide: BorderSide(color: UIColors.primary20),
              borderRadius: 16,
            ),
            child: isConcept
                ? SvgPicture.asset(
                    UISVGAssets.bookOutline,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(UIColors.primary, BlendMode.srcIn),
                  )
                : Text(
                    atom.display,
                    style: UITextStyles.dgFasehRegular(
                      32,
                    ).copyWith(color: UIColors.primary),
                    textDirection: TextDirection.rtl,
                  ),
          ),
          const Margin.vertical(4),
          Text(
            atom.label.isEmpty ? atom.display : atom.label,
            style: UITextStyles.semibold17,
          ),
        ],
      ),
    );
  }
}
