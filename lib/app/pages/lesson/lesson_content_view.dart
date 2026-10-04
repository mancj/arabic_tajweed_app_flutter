import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:arabic_tajweed_app/app/widgets/ui_kit/mono_text_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/explanation_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/tracing_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/highlighted_word.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_drawing_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/haraka_examples_grid.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_build_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/syllable_pronunciation_exercise.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/exercise.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';

import 'exercise_choice_view.dart';
import 'lesson_controller.dart';
import 'lesson_exercise_presentation.dart';
import 'option_audio_sequence.dart';

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
  const _TracingTask({required this.exercise, required this.prompt});

  final Exercise exercise;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final atom = exercise.atom;
      final onPlay = controller.hasVoice(atom)
          ? () => controller.playVoice(atom)
          : null;
      final onAutoPlay = controller.hasVoice(atom)
          ? () => controller.startVoice(atom)
          : null;
      if (controller.tracingIsAnchored) {
        return HarakaDrawingCard(
          key: ObjectKey(exercise),
          letterId: atom.kind == AtomKind.syllable && atom.letterId == 'alif'
              ? atom.id.endsWith('.kasra')
                    ? 'alif_hamza_below'
                    : 'alif_hamza_above'
              : atom.letterId!,
          title: prompt,
          hint: controller.tracingHint.value,
          onClear: controller.clearTracing,
          onPlay: onPlay,
          onAutoPlay: onAutoPlay,
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
      }
      return TracingCard(
        // Успешный ответ сразу сдвигает очередь, но эта карточка остаётся
        // видна до закрытия результата. Ключ привязан к самому заданию,
        // чтобы не потерять состояние слияния при смене индекса очереди.
        key: ObjectKey(exercise),
        badge: 'Задание',
        title: prompt,
        hint: controller.tracingHint.value,
        onClear: controller.clearTracing,
        onPlay: onPlay,
        onAutoPlay: onAutoPlay,
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

      final explanation = controller.explanationFor(atom);
      if (explanation != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Margin.vertical(8),
            ExplanationCard(
              key: ValueKey(atom.id),
              content: explanation,
              badge: controller.isReviewOnly ? 'Повторение' : 'Новая тема',
              onPlay: controller.playVoice,
              onAutoPlay: controller.startVoice,
              autoPlayLetter: true,
              hasVoice: controller.hasVoice,
              track: controller.voiceTrack,
            ),
          ],
        );
      }

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
                child: atom.id == 'concept.haraka'
                    ? HarakaExamplesOverview(
                        fathaExamples: controller.fathaIntroExamples,
                        kasraExamples: controller.kasraIntroExamples,
                        dammaExamples: controller.dammaIntroExamples,
                        summaryExamples: controller.harakaSummaryExamples,
                        onPlay: controller.playVoice,
                        track: controller.voiceTrack,
                      )
                    : null,
              )
              .animate()
              .slideX(begin: .1, curve: Curves.easeInOut, duration: .5.seconds)
              .fadeIn(),
        ],
      );
    });
  }
}

/// Объяснение формы, огласованного слога или слова перед первым вопросом.
/// Так несколько новых сочетаний не выстраиваются в длинную стопку в начале.
class _MaterialCard extends GetView<LessonController> {
  const _MaterialCard({required this.atom, this.inNotes = false});

  final Atom atom;
  final bool inNotes;

  @override
  Widget build(BuildContext context) {
    final explanation = controller.explanationFor(atom);
    final badge =
        inNotes &&
            (atom.kind == AtomKind.concept ||
                atom.kind == AtomKind.haraka ||
                atom.form == LetterForm.isolated)
        ? 'Новая тема'
        : switch (atom.kind) {
            AtomKind.word => 'Слово',
            AtomKind.syllable when atom.audioAsset != null => 'Огласовка',
            _ => 'Соединение',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inNotes) ...[const _LessonProgress(), const Margin.vertical(16)],
        if (explanation != null)
          ExplanationCard(
            key: ValueKey(atom.id),
            content: explanation,
            badge: badge,
            onPlay: controller.playVoice,
            onAutoPlay: controller.startVoice,
            autoPlayLetter: !inNotes,
            hasVoice: controller.hasVoice,
            track: controller.voiceTrack,
          )
        else ...[
          if (LessonAtomPresentation(atom).hasGlyph) ...[
            _AtomCardFor(atom: atom, autoPlay: !inNotes),
            const Margin.vertical(16),
          ],
          RuleCard(
            badge: badge,
            title: atom.label,
            text: atom.note,
            child: atom.id == 'concept.haraka'
                ? HarakaExamplesOverview(
                    fathaExamples: controller.fathaIntroExamples,
                    kasraExamples: controller.kasraIntroExamples,
                    dammaExamples: controller.dammaIntroExamples,
                    summaryExamples: controller.harakaSummaryExamples,
                    onPlay: controller.playVoice,
                    track: controller.voiceTrack,
                  )
                : switch (atom.example) {
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
      ],
    );
  }
}

/// Общая картина перед разбором отдельных соединённых форм буквы.
class _FormsOverviewCard extends GetView<LessonController> {
  const _FormsOverviewCard({required this.forms, this.inNotes = false});

  final List<Atom> forms;
  final bool inNotes;

  @override
  Widget build(BuildContext context) {
    final isolated = forms.firstWhereOrNull(
      (form) => form.form == LetterForm.isolated,
    );
    final audioAtom = isolated ?? forms.firstOrNull;
    final explanation = controller.formsExplanationFor(isolated?.letterId);
    return Column(
      key: ValueKey('forms-overview-${isolated?.letterId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inNotes) ...[const _LessonProgress(), const Margin.vertical(16)],
        if (explanation != null)
          ExplanationCard(
            content: explanation,
            badge: 'Соединение',
            footer: _audioFooter(audioAtom),
            onPlay: controller.playVoice,
            hasVoice: controller.hasVoice,
            track: controller.voiceTrack,
          )
        else
          RuleCard(
            badge: 'Соединение',
            title: 'Все формы буквы ${isolated?.display ?? ''}',
            text:
                'Посмотрите на формы и примеры в словах. Дальше разберём '
                'каждую форму отдельно.',
            footer: _audioFooter(audioAtom),
            child: LetterFormsOverview(forms: forms),
          ),
      ],
    );
  }

  Widget? _audioFooter(Atom? atom) {
    if (atom == null || !controller.hasVoice(atom)) return null;
    return SizedBox(
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
                letter: atom.display,
                onTap: () => controller.playVoice(atom),
                onAutoPlay: () => controller.startVoice(atom),
                autoPlay: !inNotes,
                track: controller.voiceTrack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Повторный просмотр использует те же карточки, что и ход урока.
class LessonNoteCard extends StatelessWidget {
  const LessonNoteCard({required this.note, super.key});

  final LessonNote note;

  @override
  Widget build(BuildContext context) => note.forms.isNotEmpty
      ? _FormsOverviewCard(forms: note.forms, inNotes: true)
      : _MaterialCard(atom: note.atom!, inNotes: true);
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
      if (card != null) return _MaterialCard(atom: card);

      final exercise = controller.current;
      if (exercise == null) return const _Centered(child: _Loader());
      final presentation = LessonExercisePresentation.from(exercise);

      if (exercise.mode == ExerciseMode.saySyllable) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LessonProgress(),
            const Margin.vertical(16),
            SyllablePronunciationExercise(
              key: ObjectKey(exercise),
              glyph: exercise.atom.display,
              result: controller.pronunciation.syllableResult.value,
              error:
                  controller.pronunciation.failure.value ==
                      PronunciationFailureKind.microphoneDenied
                  ? null
                  : controller.pronunciation.error.value,
              showFeedback:
                  !controller.wasWrong.value && !controller.wasCorrect.value,
            ),
          ],
        );
      }

      if (exercise.syllableBuildQuestion case final question?) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LessonProgress(),
            const Margin.vertical(16),
            SyllableBuildExercise(
              key: ObjectKey(exercise),
              question: question,
              selectedLetterId: controller.syllableBuildLetter.value,
              selectedMarkId: controller.syllableBuildMark.value,
              evaluation: controller.syllableBuildEvaluation.value,
              onLetterSelected: controller.selectSyllableBuildLetter,
              onMarkSelected: controller.selectSyllableBuildMark,
              onPlay: () => controller.playExerciseVoice(exercise),
              onAutoPlay: () => controller.startExerciseVoice(exercise),
              autoPlay: _canAutoPlay(controller),
              showFeedback: false,
              track: controller.voiceTrack,
            ),
          ],
        );
      }

      // У обводки карточка одна: вопрос стоит внутри неё, над сеткой.
      // Отдельная карточка сверху дублировала бы букву, которую и так
      // видно на холсте, и выталкивала холст за экран.
      if (controller.isTracingTask) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LessonProgress(),
            const Margin.vertical(16),
            _TracingTask(exercise: exercise, prompt: presentation.prompt),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LessonProgress(),
          const Margin.vertical(16),
          _QuestionFor(exercise: exercise, presentation: presentation),
          if (presentation.input == LessonInputKind.pronunciation) ...[
            const Margin.vertical(12),
            Text(
              'Нажмите и удерживайте\nкнопку ниже, чтобы начать запись',
              textAlign: TextAlign.center,
              style: UITextStyles.monoRegular12.copyWith(
                color: UIColors.secondary2,
              ),
            ),
            const Margin.vertical(4),
            Text(
              'Специально обученная нейросеть оценит ваше произношение.',
              textAlign: TextAlign.center,
              style: UITextStyles.monoRegular12.copyWith(
                color: UIColors.secondary2,
              ),
            ),
          ],
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
              slots: exercise.mode.isHarakaSequence
                  ? [
                      for (final (index, atom)
                          in exercise.sequenceOrder.indexed)
                        SequenceSlot(
                          id: 'sound-$index',
                          title: 'Звук ${index + 1}',
                          expectedAtomId:
                              exercise.mode == ExerciseMode.harakaForLetters
                              ? HarakaSyllables.markIdFor(atom)
                              : atom.id,
                          audioAsset: atom.audioAsset,
                          baseGlyph:
                              exercise.mode == ExerciseMode.harakaForLetters
                              ? HarakaSyllables.bareGlyphFor(atom)
                              : null,
                        ),
                    ]
                  : null,
              reusableOptions: exercise.mode == ExerciseMode.harakaForLetters,
              instruction: exercise.mode == ExerciseMode.harakaForLetters
                  ? 'Послушайте слот и выберите знак. Его можно использовать снова'
                  : exercise.mode.isHarakaSequence
                  ? 'Послушайте выделенный слот и выберите огласовку'
                  : 'Выберите форму для выделенного слота',
              optionNoun: exercise.mode.isHarakaSequence
                  ? 'Огласовка'
                  : 'Форма',
              playingSlotIndex: exercise.mode.isHarakaSequence
                  ? controller.sequencePlayingSlot.value
                  : null,
              onPlaySlot: exercise.mode.isHarakaSequence
                  ? (index) => controller.playSequenceSlot(exercise, index)
                  : null,
              onActiveSlotChanged: exercise.mode.isHarakaSequence
                  ? (index) => controller.startSequenceSlot(exercise, index)
                  : null,
              initialPlaced: controller.formSequenceInitialPlaced,
              slotResults: controller.wasWrong.value
                  ? controller.formSequenceSlotResults
                  : null,
              revealCorrectOrder: controller.revealFormSequenceAnswer,
              onCompleted: controller.submitFormSequence,
            )
          else if (exercise.mode == ExerciseMode.letterToSound)
            _AutoPlayingOptions(
              key: ObjectKey(exercise),
              controller: controller,
              exercise: exercise,
              presentation: presentation,
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
      LessonQuestionKind.audio => Obx(
        () => ExerciseChoiceQuestion(
          exercise: exercise,
          presentation: presentation,
          cardKey: ValueKey('sound.${_visibleExerciseIndex(controller)}'),
          nameRevealed: controller.nameRevealed.value || !hasVoice,
          onRevealName: controller.revealName,
          onPlay: hasVoice
              ? () => controller.playExerciseVoice(exercise)
              : null,
          onAutoPlay: () => controller.startExerciseVoice(exercise),
          autoPlay: _canAutoPlay(controller),
          track: controller.voiceTrack,
        ),
      ),
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
      LessonQuestionKind.harakaSequence => LetterWidgetCard(
        key: ValueKey('haraka-sequence.${_visibleExerciseIndex(controller)}'),
        letter: (exercise.prompt ?? atom).display,
        isArabic: true,
        labelText: 'Вопрос',
        question: presentation.prompt,
        showPlay: false,
      ),
      LessonQuestionKind.harakaForLetters => RuleCard(
        title: presentation.prompt,
      ),
      LessonQuestionKind.label ||
      LessonQuestionKind.glyph => ExerciseChoiceQuestion(
        exercise: exercise,
        presentation: presentation,
        cardKey: ValueKey('${exercise.mode.name}.${controller.exerciseIndex}'),
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
    this.playbackProgress = 0,
    this.isPlaying = false,
    this.onPlay,
  });

  final Exercise exercise;
  final LessonExercisePresentation presentation;
  final Atom option;
  final int index;
  final double playbackProgress;
  final bool isPlaying;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ExerciseChoiceOption(
        exercise: exercise,
        presentation: presentation,
        option: option,
        index: index,
        selected: controller.selected.value == index,
        revealed: controller.wasWrong.value || controller.wasCorrect.value,
        playbackProgress: playbackProgress,
        isPlaying: isPlaying,
        onTap: () => controller.select(index),
        onPlay: onPlay ?? () => controller.playVoice(option),
      );
    });
  }
}

class _AutoPlayingOptions extends StatefulWidget {
  const _AutoPlayingOptions({
    required this.controller,
    required this.exercise,
    required this.presentation,
    super.key,
  });

  final LessonController controller;
  final Exercise exercise;
  final LessonExercisePresentation presentation;

  @override
  State<_AutoPlayingOptions> createState() => _AutoPlayingOptionsState();
}

class _AutoPlayingOptionsState extends State<_AutoPlayingOptions> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.startOptionSequence(widget.exercise);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OptionPlaybackState>(
      valueListenable: widget.controller.optionPlayback,
      builder: (context, playback, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.exercise.options.mapIndexed(
            (index, option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                exercise: widget.exercise,
                presentation: widget.presentation,
                option: option,
                index: index,
                playbackProgress: playback.progressAt(index),
                isPlaying:
                    playback.activeIndex == index &&
                    widget.controller.voiceTrack.value.isPlaying,
                onPlay: () =>
                    widget.controller.playOptionVoice(widget.exercise, index),
              ),
            ),
          ),
          MonoTextButton(
            title: 'Прослушать ещё раз',
            icon: Icons.refresh_rounded,
            onPressed: () =>
                widget.controller.startOptionSequence(widget.exercise),
          ),
        ],
      ),
    );
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
  const _AtomCardFor({required this.atom, this.autoPlay = true, super.key});

  final Atom atom;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) =>
      LetterWidgetCard(
            isArabic: true,
            letter: atom.display,
            onPlay: controller.hasVoice(atom)
                ? () => controller.playVoice(atom)
                : null,
            onAutoPlay: () => controller.startVoice(atom),
            autoPlay: autoPlay,
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
