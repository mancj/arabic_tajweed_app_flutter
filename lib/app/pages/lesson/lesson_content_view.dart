import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide GetNumUtils;

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_widget.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_forms_overview.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_audio_waveform.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/play_control.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/answer_option.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/question_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/tracing_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';

import 'lesson_controller.dart';
import 'lesson_exercise_presentation.dart';

class LessonLoadingView extends StatelessWidget {
  const LessonLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const _Centered(child: _Loader());
}

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
      final exercise = controller.current!;
      final atom = exercise.atom;
      return TracingCard(
        // Успешный ответ сразу сдвигает очередь, но эта карточка остаётся
        // видна до закрытия результата. Ключ привязан к самому заданию,
        // чтобы не потерять состояние слияния при смене индекса очереди.
        key: ObjectKey(exercise),
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
        enabled: !controller.wasCorrect.value,
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
class LessonIntroBlock extends GetView<LessonController> {
  const LessonIntroBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final atom = controller.introAtom;
      if (atom == null) return const SizedBox.shrink();

      // У понятия нет глифа — его название и есть всё содержимое,
      // поэтому карточку с буквой показываем только для букв и знаков.
      final hasGlyph = LessonAtomPresentation(atom).hasGlyph;

      return Column(
        key: kDebugMode ? UniqueKey() : ValueKey(atom.id),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Margin.vertical(24),
          if (hasGlyph) ...[
            _AtomCardFor(
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
        _AtomCardFor(atom: atom),
        const Margin.vertical(16),
        RuleCard(
          badge: 'Соединение',
          title: atom.label,
          text: atom.note,
          child: switch (atom.example) {
            final example? => HighlightedWord(
              word: example.word,
              index: example.index,
              form: atom.form,
              fontSize: 48,
            ),
            null => null,
          },
        ),
      ],
    );
  }
}

/// Общая картина перед разбором отдельных соединённых форм буквы.
class _FormsOverviewCard extends GetView<LessonController> {
  const _FormsOverviewCard({required this.forms});

  final List<Atom> forms;

  @override
  Widget build(BuildContext context) {
    final isolated = forms.firstWhereOrNull(
      (form) => form.form == LetterForm.isolated,
    );
    final audioAtom = isolated ?? forms.firstOrNull;
    final hasVoice = audioAtom != null && controller.hasVoice(audioAtom);
    return Column(
      key: ValueKey('forms-overview-${isolated?.letterId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LessonProgress(),
        const Margin.vertical(16),
        RuleCard(
          badge: 'Соединение',
          title: 'Все формы буквы ${isolated?.display ?? ''}',
          text:
              'Посмотрите на формы и примеры в словах. Дальше разберём '
              'каждую форму отдельно.',
          footer: audioAtom != null && hasVoice
              ? SizedBox(
                  width: double.infinity,
                  height: 100,
                child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: LessonAudioWaveform(
                            height: 100,
                            track: controller.voiceTrack,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Center(
                          child: PlayControl(
                            letter: audioAtom.display,
                            onTap: () => controller.playVoice(audioAtom),
                            onAutoPlay: () => controller.startVoice(audioAtom),
                            autoPlay: true,
                            track: controller.voiceTrack,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          child: LetterFormsOverview(forms: forms),
        ),
      ],
    );
  }
}

class LessonExerciseBlock extends GetView<LessonController> {
  const LessonExerciseBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final card = controller.card.value;
      if (controller.formsOverview.isNotEmpty) {
        return _FormsOverviewCard(
          forms: List.unmodifiable(controller.formsOverview),
        );
      }
      if (card != null) return _FormCard(atom: card);

      final exercise = controller.current;
      if (exercise == null) return const _Centered(child: _Loader());
      final presentation = LessonExercisePresentation.from(exercise);

      // У обводки карточка одна: вопрос стоит внутри неё, над сеткой.
      // Отдельная карточка сверху дублировала бы букву, которую и так
      // видно на холсте, и выталкивала холст за экран.
      if (controller.isTracingTask) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LessonProgress(),
            const Margin.vertical(16),
            _TracingTask(prompt: presentation.prompt),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LessonProgress(),
          const Margin.vertical(16),
          _QuestionFor(exercise: exercise, presentation: presentation),
          const Margin.vertical(16),
          if (presentation.input == LessonInputKind.pronunciation)
            _SayNameFeedback(exercise: exercise)
          else if (presentation.input == LessonInputKind.formSequence)
            FormSequenceExercise(
              key: ValueKey(
                'form-sequence.${_visibleExerciseIndex(controller)}.'
                '${controller.formSequenceAttempt.value}',
              ),
              options: exercise.options,
              initialPlaced: controller.formSequenceInitialPlaced,
              slotResults: controller.wasWrong.value
                  ? controller.formSequenceSlotResults
                  : null,
              revealCorrectOrder: controller.revealFormSequenceAnswer,
              onCompleted: controller.submitFormSequence,
            )
          else if (exercise.isChoice)
            ...exercise.options.mapIndexed(
              (index, option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  exercise: exercise,
                  presentation: presentation,
                  option: option,
                  index: index,
                ),
              ),
            )
          else
            _StubTask(exercise: exercise, presentation: presentation),
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
        wavy: true,
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
  const _QuestionFor({required this.exercise, required this.presentation});

  final Exercise exercise;
  final LessonExercisePresentation presentation;

  @override
  Widget build(BuildContext context) {
    final atom = exercise.atom;
    final hasVoice = controller.hasExerciseVoice(exercise);

    return switch (presentation.question) {
      LessonQuestionKind.audio => Obx(() {
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
              question: presentation.prompt,
              subtitle: named ? atom.label : null,
              onPlay: hasVoice
                  ? () => controller.playExerciseVoice(exercise)
                  : null,
              onAutoPlay: () => controller.startExerciseVoice(exercise),
              autoPlay: _canAutoPlay(controller),
              track: controller.voiceTrack,
            ),
            if (!named)
              TextButton(
                onPressed: controller.revealName,
                child: Text(
                  presentation.audioHintAction,
                  style: UITextStyles.monoRegular14,
                ),
              ),
          ],
        );
      }),
      LessonQuestionKind.formSequence => LetterWidgetCard(
        key: ValueKey('position.${_visibleExerciseIndex(controller)}'),
        letter: (exercise.prompt ?? atom).display,
        isArabic: true,
        labelText: 'Вопрос',
        question: presentation.prompt,
        onPlay: hasVoice ? () => controller.playExerciseVoice(exercise) : null,
        onAutoPlay: () => controller.startExerciseVoice(exercise),
        autoPlay: _canAutoPlay(controller),
        track: controller.voiceTrack,
      ),
      // Старые режимы с именем буквы: в уроках не строятся, см. ExerciseMode.
      LessonQuestionKind.label => QuestionCard(
        badge: 'Вопрос',
        question: presentation.prompt,
        subject: atom.label,
        subjectFont: UITextStyles.fontOnest,
      ),
      // Без кнопки звучания: в задании «назови букву» озвучка и была бы
      // ответом.
      LessonQuestionKind.glyph => LetterWidgetCard(
        key: ValueKey('${exercise.mode.name}.${controller.exerciseIndex}'),
        letter: atom.display,
        labelText: 'Вопрос',
        question: presentation.prompt,
        showPlay: false,
        isArabic: true,
      ),
    };
  }
}

int _visibleExerciseIndex(LessonController controller) {
  final index = controller.exerciseIndex;
  return controller.wasCorrect.value ? index - 1 : index;
}

bool _canAutoPlay(LessonController controller) =>
    !controller.wasCorrect.value && !controller.wasWrong.value;

class _OptionTile extends GetView<LessonController> {
  const _OptionTile({
    required this.exercise,
    required this.presentation,
    required this.option,
    required this.index,
  });

  final Exercise exercise;
  final LessonExercisePresentation presentation;
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
        child: presentation.optionsAreGlyphs
            ? _Glyph(atom: option, size: 28)
            : Text(option.label, style: UITextStyles.regular17),
      );
    });
  }
}

/// Место будущего задания: режим уже выбран планировщиком, а его экран
/// ещё не написан. Кнопка «Ответить» засчитывает такое задание верным —
/// иначе прогресс упрётся в незаконченный UI.
class _StubTask extends StatelessWidget {
  const _StubTask({required this.exercise, required this.presentation});

  final Exercise exercise;
  final LessonExercisePresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
            presentation.placeholderHint ?? 'Задание пока недоступно.',
            style: UITextStyles.regular17,
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
class _AtomCardFor extends GetView<LessonController> {
  const _AtomCardFor({required this.atom, super.key});

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
    style: UITextStyles.arabicRegular(size),
    textDirection: TextDirection.rtl,
  );
}
