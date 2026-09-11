import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide GetNumUtils;

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/media/single_sound_effect.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/answer_option.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/record_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/question_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/tracing_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';

import 'lesson_controller.dart';

export 'lesson_binding.dart';
export 'lesson_controller.dart';

/// Экран урока: одна сцена, которая переключает режимы упражнений.
///
/// Блок «новое» показывает атом без проверки, дальше идёт очередь заданий.
/// Ошибка не выкидывает из урока — верный ответ подсвечивается, задание
/// возвращается в конец очереди. См. SPEC.md §5.
class LessonPage extends GetView<LessonController> {
  static const routeName = '/lesson';

  const LessonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ResultSheetHost(controller: controller);
  }
}

class _ResultSheetHost extends StatefulWidget {
  const _ResultSheetHost({required this.controller});

  final LessonController controller;

  @override
  State<_ResultSheetHost> createState() => _ResultSheetHostState();
}

class _ResultSheetHostState extends State<_ResultSheetHost> {
  late final Worker _correctWorker;
  late final Worker _wrongWorker;
  bool _sheetOpen = false;

  LessonController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _correctWorker = ever(controller.wasCorrect, (_) => _showResultSheet());
    _wrongWorker = ever(controller.wasWrong, (_) => _showResultSheet());
  }

  void _showResultSheet() {
    if (!mounted || _sheetOpen) return;
    if (!controller.wasCorrect.value && !controller.wasWrong.value) return;

    _sheetOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: UIColors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _ResultSheet(controller: controller),
      );
      _sheetOpen = false;
    });
  }

  @override
  void dispose() {
    _correctWorker.dispose();
    _wrongWorker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: controller.isReviewOnly ? 'Повторение' : 'Урок',
      bottomBar: Obx(() => _BottomBar(stage: controller.stage.value)),
      builder: (context, insets) => Obx(() {
        final stage = controller.stage.value;
        return SingleChildScrollView(
          // Прокрутку у холста отбирает он сам, забирая жест в арене
          // ([DrawingCanvas]). Всей странице замирать не нужно: карточка
          // обводки бывает выше экрана, и до кнопок надо доезжать.
          padding: insets,
          child: switch (stage) {
            LessonStage.loading => const _Centered(child: _Loader()),
            LessonStage.intro => const _IntroBlock(),
            LessonStage.exercise => const _ExerciseBlock(),
            LessonStage.finished => const _FinishBlock(),
          },
        );
      }),
    );
  }
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.controller});

  final LessonController controller;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet>
    with SingleTickerProviderStateMixin {
  static const _autoAdvanceDuration = Duration(seconds: 5);

  late final SingleSoundEffect _answerSound;
  AnimationController? _autoAdvanceController;
  bool _advancing = false;

  LessonController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _answerSound = SingleSoundEffect(
      assetPath: controller.wasCorrect.value
          ? 'audio/correct_answer.m4a'
          : 'audio/incorrect.m4a',
    );
    unawaited(_answerSound.play());
    if (controller.wasCorrect.value) {
      _autoAdvanceController = AnimationController(
        vsync: this,
        duration: _autoAdvanceDuration,
      )..addStatusListener(_handleAutoAdvanceStatus);
      _autoAdvanceController!.forward();
    }
  }

  void _handleAutoAdvanceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) unawaited(_advance());
  }

  Future<void> _advance() async {
    if (_advancing || !mounted) return;
    setState(() => _advancing = true);
    _autoAdvanceController?.stop();
    await controller.submit();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _autoAdvanceController?.dispose();
    unawaited(_answerSound.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = controller.wasCorrect.value;
    final exercise = controller.current;
    final label = exercise?.atom.label ?? 'ответ';
    final isPronunciation = exercise?.mode == ExerciseMode.sayName;
    final isFormSequence = exercise?.mode == ExerciseMode.positionToForm;
    final check = controller.pronunciation.result.value;

    final title = correct
        ? (isPronunciation ? 'Правильно произнесено' : 'Верно!')
        : 'Попробуйте ещё раз';
    final text = correct
        ? isPronunciation && check != null
              ? 'Слышно: ${check.heard}.'
              : isPronunciation
              ? 'Ответ засчитан.'
              : isFormSequence
              ? 'Все формы расставлены по своим местам.'
              : exercise?.mode.isTracing == true
              ? 'Буква $label написана правильно.'
              : 'Правильный ответ: $label.'
        : isPronunciation && check != null
        ? 'Услышано: ${check.heard}. Это буква $label.'
        : isFormSequence
        ? 'Проверьте порядок форм и попробуйте ещё раз.'
        : exercise?.mode.isTracing == true
        ? 'Попробуйте написать букву $label ещё раз.'
        : 'Правильный ответ: $label.';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: UIColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: UIColors.secondary1,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              correct ? Icons.check_circle_rounded : Icons.refresh_rounded,
              size: 41,
              color: correct ? UIColors.primary : UIColors.text,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: UITextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: UITextStyles.regularText,
              textAlign: TextAlign.center,
            ),
            if (correct) ...[
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _autoAdvanceController!,
                builder: (context, _) {
                  final progress = _autoAdvanceController!.value;
                  final secondsLeft =
                      (_autoAdvanceDuration.inSeconds * (1 - progress)).ceil();
                  return Semantics(
                    label: 'Автоматический переход',
                    value: 'Через $secondsLeft секунд',
                    child: Column(
                      key: const ValueKey('correct-answer-auto-progress'),
                      children: [
                        Text(
                          'Далее автоматически через $secondsLeft сек.',
                          style: UITextStyles.hint,
                        ),
                        const SizedBox(height: 8),
                        LessonProgressBar(value: progress, height: 8),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NextButton(
                title: correct ? 'Продолжить' : 'Попробовать ещё раз',
                enabled: !_advancing,
                onTap: _advance,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends GetView<LessonController> {
  const _BottomBar({required this.stage});

  final LessonStage stage;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      LessonStage.loading => const SizedBox.shrink(),
      LessonStage.intro => NextButton(
        title: 'Понятно',
        onTap: controller.nextIntro,
      ),
      LessonStage.exercise => Obx(() {
        if (controller.wasWrong.value) {
          return const SizedBox.shrink();
        }

        // Карточка формы перекрывает задание: сначала объяснение,
        // потом вопрос про ту же букву.
        if (controller.card.value != null) {
          return NextButton(title: 'Понятно', onTap: controller.dismissCard);
        }

        final exercise = controller.current;
        final isTracing = controller.isTracingTask;
        final isSayName = controller.isSayNameTask;
        final isFormSequence = exercise?.mode == ExerciseMode.positionToForm;

        // У заглушки нет своей проверки — обе ветки задаёт человек.
        // TODO(stub): убрать вторую кнопку вместе с заглушками.
        final isStub =
            exercise != null &&
            !exercise.isChoice &&
            !controller.isTracingTask &&
            !controller.isSayNameTask;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Только в отладке: «верно» пишет чистый ответ и двигает прогресс,
            // «пропустить» не пишет ничего. Оба нужны, чтобы быстро дойти
            // до нужного места курса.
            if (kDebugMode) const _DebugBar(),
            if (isTracing)
              _TracingBar(mode: exercise!.mode)
            else if (isSayName)
              const _RecordBar()
            else if (isFormSequence)
              const SizedBox.shrink()
            else if (isStub)
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: NextButton(
                      title: 'Ответить',
                      onTap: () => controller.submitStub(correct: true),
                    ),
                  ),
                  const Margin.horizontal(10),
                  Expanded(
                    child: NextButton(
                      title: 'Ошибиться',
                      onTap: () => controller.submitStub(correct: false),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: NextButton(
                  title: controller.wasWrong.value ? 'Ясно' : 'Ответить',
                  enabled: controller.canSubmit,
                  onTap: controller.canSubmit
                      ? () => controller.submit()
                      : null,
                ),
              ),
          ],
        );
      }),
      LessonStage.finished => NextButton(title: 'Завершить', onTap: Get.back),
    };
  }
}

class _DebugBar extends GetView<LessonController> {
  const _DebugBar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DebugAction(text: 'Ответить верно', onTap: controller.answerCorrectly),
        const Margin.horizontal(24),
        _DebugAction(text: 'Пропустить', onTap: controller.skipExercise),
      ],
    ),
  );
}

/// Текстовая кнопка отладочной панели: без рамки, чтобы не спутать
/// с настоящими кнопками урока.
class _DebugAction extends StatelessWidget {
  const _DebugAction({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: UITextStyles.hint),
    ),
  );
}

/// Нижняя панель заданий на письмо.
///
/// Части засчитываются сами, поэтому кнопка только подтверждает готовое.
/// По памяти рядом стоит выход для того, кто букву не вспомнил; по контуру
/// он не нужен — буква и так перед глазами.
class _TracingBar extends GetView<LessonController> {
  const _TracingBar({required this.mode});

  final ExerciseMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mode == ExerciseMode.traceFromMemory)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.giveUpTracing,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 6),
              child: Text('Не помню, показать', style: UITextStyles.hint),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: Obx(
            () => NextButton(
              title: 'Готово',
              enabled: controller.canSubmit,
              onTap: controller.canSubmit ? () => controller.submit() : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Нижняя панель задания «назови букву». Если сервера нет, под кнопкой
/// выход из задания.
class _RecordBar extends GetView<LessonController> {
  const _RecordBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final checker = controller.pronunciation;
      return RecordBar(
        recording: checker.isRecording.value,
        checking: checker.isChecking.value,
        idleHint: 'Удерживайте кнопку и назовите букву',
        onPressStart: controller.startRecording,
        onPressEnd: controller.stopRecording,
        footer: checker.error.value == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.skipExercise,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Продолжить без произношения',
                        style: UITextStyles.hint,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.optOutOfPronunciation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Больше не предлагать произношение',
                        style: UITextStyles.hint,
                      ),
                    ),
                  ),
                ],
              ),
      );
    });
  }
}

/// Отклик сервера под карточкой буквы: что он услышал и что делать
/// дальше. Пока записи не было — пусто, карточка вопроса говорит сама.
class _SayNameFeedback extends GetView<LessonController> {
  const _SayNameFeedback({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = controller.pronunciation.error.value;
      if (error != null) {
        return RuleCard(
          badge: 'Не вышло',
          title: error,
          text: 'Попробуйте ещё раз или продолжите занятие без произношения.',
        );
      }

      final check = controller.pronunciation.result.value;
      if (check == null || check.matched) return const SizedBox.shrink();

      final heard = 'Услышано: ${check.heard} — ${check.hint}';
      final label = exercise.atom.label;

      if (check.recording.warning case final warning?) {
        return RuleCard(
          badge: 'Не разобрать',
          title: 'Запись: $warning',
          text: 'Попытка не считается. Скажите ближе к микрофону, в тишине.',
        );
      }
      if (controller.wasWrong.value) {
        return RuleCard(
          badge: 'Ошибка',
          title: heard,
          text: 'Это буква $label. Нажмите «Ясно» и назовите её ещё раз.',
        );
      }
      return RuleCard(
        badge: 'Не то',
        title: heard,
        text: 'Ещё одна попытка: это буква $label.',
      );
    });
  }
}

/// Задание на письмо: общая карточка [TracingCard]. Здесь она получает
/// вопрос, правило показа после промахов и оценку из урока.
class _TracingTask extends GetView<LessonController> {
  const _TracingTask({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final atom = controller.current!.atom;
      return TracingCard(
        key: ValueKey('tracing.${_visibleExerciseIndex(controller)}'),
        badge: 'Задание',
        title: prompt,
        hint: controller.tracingHint.value,
        onClear: controller.clearTracing,
        onPlay: controller.hasVoice(atom)
            ? () => controller.playVoice(atom)
            : null,
        onAutoPlay: controller.hasVoice(atom)
            ? () => controller.startVoice(atom)
            : null,
        autoPlay: _canAutoPlay(controller),
        track: controller.voiceTrack,
        playbackKey: atom.display,
        controller: controller.drawing,
        matcher: LessonController.tracingMatcher,
        mode: controller.canvasMode,
        shape: controller.tracingShape.value,
        missesBeforeReveal: controller.rules.tracingMissesBeforeReveal,
        onProgress: controller.onTracingProgress,
        onReveal: controller.onTracingRevealed,
        onMerged: controller.onTracingMerged,
      );
    });
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) =>
      CircularProgressIndicator(color: UIColors.primary);
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 320, child: Center(child: child));
}

/// Блок «новое»: атом показывают без проверки. Спрашивать его начнут
/// в следующем блоке — сначала надо дать посмотреть.
class _IntroBlock extends GetView<LessonController> {
  const _IntroBlock();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final atom = controller.introAtom;
      if (atom == null) return const SizedBox.shrink();

      // У понятия нет глифа — его название и есть всё содержимое,
      // поэтому карточку с буквой показываем только для букв и знаков.
      final isConcept = atom.kind == AtomKind.concept;

      return Column(
        key: kDebugMode ? UniqueKey() : ValueKey(atom.id),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Margin.vertical(24),
          if (!isConcept) ...[
            _LetterCardFor(
              atom: atom,
              key: kDebugMode ? UniqueKey() : ValueKey(atom.id),
            ),
            const Margin.vertical(16),
          ],
          RuleCard(
                badge: controller.isReviewOnly ? 'Повторение' : 'Новая тема',
                title: atom.label,
                text: atom.note,
              )
              .animate()
              .slideX(begin: .1, curve: Curves.easeInOut, duration: .5.seconds)
              .fadeIn(),
        ],
      );
    });
  }
}

/// Объяснение одной формы буквы перед первым заданием на неё.
///
/// Не в общем блоке «новое», а здесь: правило про соединение читается,
/// когда есть на что смотреть, а не десятью карточками подряд в начале.
class _FormCard extends GetView<LessonController> {
  const _FormCard({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LessonProgress(),
        const Margin.vertical(16),
        _LetterCardFor(atom: atom),
        const Margin.vertical(16),
        RuleCard(
          badge: 'Соединение',
          title: atom.label,
          text: atom.note,
          child: switch (atom.example) {
            final example? => HighlightedWord(
              word: example.word,
              index: example.index,
              fontSize: 48,
            ),
            null => null,
          },
        ),
      ],
    );
  }
}

class _ExerciseBlock extends GetView<LessonController> {
  const _ExerciseBlock();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final card = controller.card.value;
      if (card != null) return _FormCard(atom: card);

      final exercise = controller.current;
      if (exercise == null) return const _Centered(child: _Loader());

      // У обводки карточка одна: вопрос стоит внутри неё, над сеткой.
      // Отдельная карточка сверху дублировала бы букву, которую и так
      // видно на холсте, и выталкивала холст за экран.
      if (controller.isTracingTask) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LessonProgress(),
            const Margin.vertical(16),
            _TracingTask(prompt: _tracingPrompt(exercise)),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LessonProgress(),
          const Margin.vertical(16),
          _QuestionFor(exercise: exercise),
          const Margin.vertical(16),
          if (exercise.mode == ExerciseMode.sayName)
            _SayNameFeedback(exercise: exercise)
          else if (exercise.mode == ExerciseMode.positionToForm)
            FormSequenceExercise(
              key: ValueKey(
                'form-sequence.${_visibleExerciseIndex(controller)}.'
                '${controller.formSequenceAttempt.value}',
              ),
              options: exercise.options,
              onCompleted: controller.submitFormSequence,
            )
          else if (exercise.isChoice)
            ...exercise.options.mapIndexed(
              (index, option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  exercise: exercise,
                  option: option,
                  index: index,
                ),
              ),
            )
          else
            _StubTask(exercise: exercise),
        ],
      );
    });
  }
}

class _LessonProgress extends GetView<LessonController> {
  const _LessonProgress();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LessonProgressBar(
        value: controller.progress,
        debugLabel: kDebugMode
            ? '№ ${controller.exerciseNumber} из ${controller.totalExercises}'
            : null,
      ),
    );
  }
}

/// Карточка вопроса. Задание с выбором строится на звуке и арабских
/// буквах, без русского имени: на слух буква звучит, а вместо глифа стоит
/// знак вопроса; в раскладке форм отдельная форма остаётся образцом.
/// Имя появляется только как подмена, если звука нет или его не слышно.
class _QuestionFor extends GetView<LessonController> {
  const _QuestionFor({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final atom = exercise.atom;
    final hasVoice = controller.hasVoice(atom);

    return switch (exercise.mode) {
      ExerciseMode.soundToLetter => Obx(() {
        final named = controller.nameRevealed.value || !hasVoice;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ключ по номеру задания: у всех заданий на слух в карточке один
            // знак вопроса, а одна буква спрашивается несколько раз подряд.
            // Без ключа карточка не пересоздаётся между заданиями, а звук
            // запускается сам только у новой карточки.
            LetterWidgetCard(
              key: ValueKey('sound.${_visibleExerciseIndex(controller)}'),
              letter: '?',
              glyph: SvgPicture.asset(
                UISVGAssets.questionMark,
                height: 48,
                colorFilter: ColorFilter.mode(
                  UIColors.primary,
                  BlendMode.srcIn,
                ),
              ),
              isArabic: false,
              labelText: 'Вопрос',
              question: _promptFor(exercise),
              subtitle: named ? atom.label : null,
              onPlay: hasVoice ? () => controller.playVoice(atom) : null,
              onAutoPlay: () => controller.startVoice(atom),
              autoPlay: _canAutoPlay(controller),
              track: controller.voiceTrack,
            ),
            if (!named)
              TextButton(
                onPressed: controller.revealName,
                child: Text(
                  'Не слышно? Показать название',
                  style: UITextStyles.regular14,
                ),
              ),
          ],
        );
      }),
      ExerciseMode.positionToForm => LetterWidgetCard(
        key: ValueKey('position.${_visibleExerciseIndex(controller)}'),
        letter: (exercise.prompt ?? atom).display,
        isArabic: true,
        labelText: 'Вопрос',
        question: _promptFor(exercise),
        onPlay: hasVoice ? () => controller.playVoice(atom) : null,
        onAutoPlay: () => controller.startVoice(atom),
        autoPlay: _canAutoPlay(controller),
        track: controller.voiceTrack,
      ),
      // Старые режимы с именем буквы: в уроках не строятся, см. ExerciseMode.
      ExerciseMode.nameToForm => QuestionCard(
        badge: 'Вопрос',
        question: _promptFor(exercise),
        subject: atom.label,
        subjectFont: UITextStyles.fontOnest,
      ),
      // Без кнопки звучания: в задании «назови букву» озвучка и была бы
      // ответом.
      _ => LetterWidgetCard(
        key: ValueKey('${exercise.mode.name}.${controller.exerciseIndex}'),
        letter: atom.display,
        labelText: 'Вопрос',
        question: _promptFor(exercise),
        showPlay: false,
        isArabic: true,
      ),
    };
  }
}

/// В письме по памяти контура нет и глиф не показываем — иначе задание
/// превращается в обводку по образцу. Поэтому букву называют словами:
/// человек должен вспомнить её начертание, а не срисовать.
String _tracingPrompt(Exercise exercise) => exercise.mode == ExerciseMode.trace
    ? 'Обведите по контуру: ${exercise.atom.label}'
    : 'Напишите по памяти: ${exercise.atom.label}';

int _visibleExerciseIndex(LessonController controller) {
  final index = controller.exerciseIndex;
  return controller.wasCorrect.value ? index - 1 : index;
}

bool _canAutoPlay(LessonController controller) =>
    !controller.wasCorrect.value && !controller.wasWrong.value;

String _promptFor(Exercise exercise) => switch (exercise.mode) {
  ExerciseMode.positionToForm => 'Расставьте формы буквы по местам',
  ExerciseMode.formToName =>
    exercise.atom.kind == AtomKind.syllable
        ? 'Какие буквы здесь соединены?'
        : 'Как называется эта буква?',
  ExerciseMode.nameToForm =>
    exercise.atom.kind == AtomKind.syllable
        ? 'Выберите сочетание букв'
        : 'Как пишется буква?',
  ExerciseMode.distinguishDots => 'Какая из них — эта буква?',
  ExerciseMode.findInWord => 'Найдите эту букву в слове',
  ExerciseMode.formToPosition => 'Где в слове стоит эта форма?',
  ExerciseMode.soundToLetter => 'Послушайте и выберите букву',
  ExerciseMode.letterToSound => 'Как звучит эта буква?',
  ExerciseMode.trace => 'Обведите букву пальцем',
  ExerciseMode.traceFromMemory => 'Напишите букву по памяти',
  ExerciseMode.assemble => 'Соберите слог справа налево',
  ExerciseMode.sayName => 'Назовите эту букву вслух',
};

/// Варианты — арабские глифы; подписи словами только у старых режимов
/// с именем буквы.
bool _optionsAreGlyphs(ExerciseMode mode) => switch (mode) {
  ExerciseMode.soundToLetter ||
  ExerciseMode.positionToForm ||
  ExerciseMode.nameToForm => true,
  _ => false,
};

/// Чего не хватает режиму, чтобы работать по-настоящему.
String _stubHintOf(ExerciseMode mode) => switch (mode) {
  ExerciseMode.trace || ExerciseMode.traceFromMemory =>
    'Заглушка. Холст обводки работает, но для этой формы буквы нет SVG '
        'с осевыми линиями — их предстоит нарисовать, см. SPEC.md §12.',
  ExerciseMode.assemble =>
    'Заглушка. Сборка слога появится на этапе 2, когда откроется понятие '
        '«как буквы соединяются».',
  ExerciseMode.soundToLetter || ExerciseMode.letterToSound =>
    'Заглушка. Озвучку ещё не записали: 28 имён букв и 28 звуков '
        'предстоит сгенерировать, см. SPEC.md §12.',
  _ => 'Заглушка: этот режим ещё не собран.',
};

class _OptionTile extends GetView<LessonController> {
  const _OptionTile({
    required this.exercise,
    required this.option,
    required this.index,
  });

  final Exercise exercise;
  final Atom option;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selected.value == index;
      final revealed = controller.wasWrong.value || controller.wasCorrect.value;
      final isAnswer = index == exercise.answerIndex;

      // После ошибки верный ответ подсвечивается всегда, а выбранный
      // неверный — красным: человек должен увидеть, что именно перепутал.
      final color = switch ((revealed, isAnswer, selected)) {
        (true, true, _) => UIColors.primary,
        (true, false, true) => UIColors.secondary1,
        _ => UIColors.primary,
      };

      return AnswerOption(
        selected: selected || (revealed && isAnswer),
        accent: color,
        onTap: () => controller.select(index),
        child: _optionsAreGlyphs(exercise.mode)
            ? _Glyph(atom: option, size: 28)
            : Text(option.label, style: UITextStyles.regularTextDark),
      );
    });
  }
}

/// Место будущего задания: режим уже выбран планировщиком, а его экран
/// ещё не написан. Кнопка «Ответить» засчитывает такое задание верным —
/// иначе прогресс упрётся в незаконченный UI.
class _StubTask extends StatelessWidget {
  const _StubTask({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 20,
        borderSide: BorderSide(color: UIColors.secondary1),
      ),
      child: Column(
        children: [
          _Glyph(atom: exercise.atom, size: 64),
          const Margin.vertical(12),
          Text(
            _stubHintOf(exercise.mode),
            style: UITextStyles.regularText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Карточка буквы: глиф, фоновая графика и кнопка звучания.
///
/// Кнопка появляется только там, где запись есть. У понятий и слогов её нет,
/// и мёртвая кнопка обещала бы звук, которого не будет.
class _LetterCardFor extends GetView<LessonController> {
  const _LetterCardFor({required this.atom, super.key});

  final Atom atom;

  @override
  Widget build(BuildContext context) =>
      LetterWidgetCard(
            isArabic: true,
            letter: atom.display,
            onPlay: controller.hasVoice(atom)
                ? () => controller.playVoice(atom)
                : null,
            onAutoPlay: () => controller.startVoice(atom),
            autoPlay: true,
            track: controller.voiceTrack,
          )
          .animate()
          .slideX(begin: .2, curve: Curves.easeInOut, duration: .3.seconds)
          .fadeIn();
}

/// Глиф рисуется шрифтом. Осевые SVG для обводки уже есть в assets/svg,
/// но здесь нужен именно готовый вид буквы, а не контур для письма.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.atom, required this.size});

  final Atom atom;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    atom.display,
    style: TextStyle(
      fontFamily: UITextStyles.fontScheherazadeNew,
      fontSize: size,
      color: UIColors.text,
    ),
    textDirection: TextDirection.rtl,
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Text(
      text,
      style: UITextStyles.regularText,
      textAlign: TextAlign.center,
    ),
  );
}

class _FinishBlock extends GetView<LessonController> {
  const _FinishBlock();

  @override
  Widget build(BuildContext context) {
    final introduced = controller.sessionIntroduced;

    return Column(
      children: [
        const Margin.vertical(48),
        Text(
          controller.isReviewOnly ? 'Повторили' : 'Урок пройден',
          style: UITextStyles.pageTitleSemibold,
        ),
        const Margin.vertical(16),
        if (introduced.isNotEmpty) ...[
          Text(
            controller.isReviewOnly ? 'Повторили' : 'Сегодня разобрали',
            style: UITextStyles.regularText,
          ),
          const Margin.vertical(12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [for (final atom in introduced) _LearnedChip(atom: atom)],
          ),
        ],
        const Margin.vertical(24),
        // Причина плана видна только в отладке: пользователю она ничего
        // не говорит, а нам объясняет, почему урок вышел именно таким.
        if (kDebugMode) _Hint(text: controller.planReason),
      ],
    );
  }
}

class _LearnedChip extends StatelessWidget {
  const _LearnedChip({required this.atom});

  final Atom atom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 16,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (atom.kind != AtomKind.concept) ...[
            _Glyph(atom: atom, size: 28),
            const Margin.horizontal(10),
          ],
          Text(atom.label, style: UITextStyles.semiboldText),
        ],
      ),
    );
  }
}
