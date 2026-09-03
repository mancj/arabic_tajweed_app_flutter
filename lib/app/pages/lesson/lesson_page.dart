import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/answer_option.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/question_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/rule_card.dart';
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
    return AppScaffold(
      title: controller.isReviewOnly ? 'Повторение' : 'Урок',
      bottomBar: Obx(() => _BottomBar(stage: controller.stage.value)),
      builder: (context, insets) => Obx(() {
        final stage = controller.stage.value;
        return SingleChildScrollView(
          // Пока на экране холст, страница не прокручивается: вертикальный
          // штрих по букве иначе выигрывает жест прокрутка, а не рисование.
          physics: controller.isTracingTask
              ? const NeverScrollableScrollPhysics()
              : null,
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
        // Карточка формы перекрывает задание: сначала объяснение,
        // потом вопрос про ту же букву.
        if (controller.card.value != null) {
          return NextButton(title: 'Понятно', onTap: controller.dismissCard);
        }

        final exercise = controller.current;
        final revealed = controller.wasWrong.value;
        final isTracing = controller.isTracingTask && !revealed;

        // У заглушки нет своей проверки — обе ветки задаёт человек.
        // TODO(stub): убрать вторую кнопку вместе с заглушками.
        final isStub =
            exercise != null &&
            !exercise.isChoice &&
            !controller.isTracingTask &&
            !revealed;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Пропуск только в отладке: нужен, чтобы быстро дойти до нужного
            // экрана. Ответ никуда не пишется, прогресс не искажается.
            if (kDebugMode) const _SkipButton(),
            if (isTracing)
              _TracingBar(mode: exercise!.mode)
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

class _SkipButton extends GetView<LessonController> {
  const _SkipButton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.skipExercise,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Пропустить', style: UITextStyles.hint),
      ),
    ),
  );
}

/// Нижняя панель заданий на письмо.
///
/// По контуру судит кнопка «Проверить»: буква сверяется целиком. По памяти
/// части засчитываются сами, поэтому кнопка только подтверждает готовое —
/// и рядом стоит выход для того, кто букву не вспомнил.
class _TracingBar extends GetView<LessonController> {
  const _TracingBar({required this.mode});

  final ExerciseMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == ExerciseMode.trace) {
      return SizedBox(
        width: double.infinity,
        child: NextButton(title: 'Проверить', onTap: controller.checkTracing),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.giveUpTracing,
          child: const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 6),
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

/// Задание на письмо: та же карточка с прописной сеткой, что и на экране
/// знакомства с буквой. Контур под штрихами показывается или прячется —
/// это и есть разница между режимами.
class _TracingTask extends GetView<LessonController> {
  const _TracingTask({required this.prompt});

  final String prompt;

  /// Размеры карточки в макете. Холст с сеткой сохраняет пропорции экрана
  /// знакомства с буквой, а сверху добавлена строка вопроса.
  static const _height = 424.0;
  static const _canvasTop = 62.0;
  static const _canvasHeight = 329.0;
  static const _guidesTop = 148.0;

  @override
  Widget build(BuildContext context) {
    return LetterCard(
      designHeight: _height,
      builder: (context, k) => [
        Positioned(
          top: 22 * k,
          left: 20 * k,
          right: 20 * k,
          child: IgnorePointer(
            child: Text(
              prompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: UITextStyles.fontOnest,
                fontWeight: FontWeight.w600,
                fontSize: 18 * k,
                color: UIColors.ink,
              ),
            ),
          ),
        ),
        Positioned(
          top: _guidesTop * k,
          left: 0,
          right: 0,
          height: LetterGuides.designHeight * k,
          child: Center(child: LetterGuides(k: k)),
        ),
        // Холст выше сетки: у букв общий квадратный кадр с запасом под
        // верхние и нижние точки, и вписывается в карточку именно он.
        Positioned(
          top: _canvasTop * k,
          left: 0,
          right: 0,
          height: _canvasHeight * k,
          child: Center(
            child: SizedBox(
              width: LetterGuides.designWidth * k,
              child: Obx(
                () => DrawingCanvas(
                  controller: controller.drawing,
                  matcher: LessonController.tracingMatcher,
                  mode: controller.canvasMode,
                  placeholder: controller.tracingShape.value,
                  color: UIColors.tealDark,
                  placeholderColor: UIColors.letterGhost,
                  placeholderPadding: 0,
                  onProgress: controller.onTracingProgress,
                  onMerged: controller.onTracingMerged,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 18 * k,
          left: 20 * k,
          right: 20 * k,
          child: IgnorePointer(
            child: Obx(
              () => Text(
                controller.tracingHint.value,
                textAlign: TextAlign.center,
                style: UITextStyles.hint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) =>
      const CircularProgressIndicator(color: UIColors.primary);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Margin.vertical(24),
          if (!isConcept) ...[
            _GlyphCard(atom: atom, big: true),
            const Margin.vertical(16),
          ],
          RuleCard(
            badge: controller.isReviewOnly ? 'Повторение' : 'Новая тема',
            title: atom.label,
            text: atom.note,
          ),
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
        LessonProgressBar(value: controller.progress),
        const Margin.vertical(16),
        _GlyphCard(atom: atom, big: true),
        const Margin.vertical(16),
        RuleCard(badge: 'Соединение', title: atom.label, text: atom.note),
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
            LessonProgressBar(value: controller.progress),
            const Margin.vertical(16),
            _TracingTask(prompt: _tracingPrompt(exercise)),
          ],
        );
      }

      // В режиме «выбери начертание» спрашивают про название буквы,
      // поэтому в карточке стоит имя, а в вариантах — глифы.
      final byName = exercise.mode == ExerciseMode.nameToForm;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LessonProgressBar(value: controller.progress),
          const Margin.vertical(16),
          QuestionCard(
            badge: 'Вопрос',
            question: _promptOf(exercise.mode),
            subject: byName ? exercise.atom.label : exercise.atom.display,
            subjectFont: byName
                ? UITextStyles.fontOnest
                : UITextStyles.fontScheherazadeNew,
            ghost: byName ? null : exercise.atom.display,
          ),
          const Margin.vertical(16),
          if (exercise.isChoice)
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

/// В письме по памяти контура нет и глиф не показываем — иначе задание
/// превращается в обводку по образцу. Поэтому букву называют словами:
/// человек должен вспомнить её начертание, а не срисовать.
String _tracingPrompt(Exercise exercise) =>
    exercise.mode == ExerciseMode.trace
    ? 'Обведите по контуру: ${exercise.atom.label}'
    : 'Напишите по памяти: ${exercise.atom.label}';

String _promptOf(ExerciseMode mode) => switch (mode) {
  ExerciseMode.formToName => 'Как называется эта буква?',
  ExerciseMode.nameToForm => 'Выберите, как она пишется',
  ExerciseMode.distinguishDots => 'Какая из них — эта буква?',
  ExerciseMode.findInWord => 'Найдите эту букву в слове',
  ExerciseMode.formToPosition => 'Где в слове стоит эта форма?',
  ExerciseMode.soundToLetter => 'Послушайте и выберите букву',
  ExerciseMode.letterToSound => 'Как звучит эта буква?',
  ExerciseMode.trace => 'Обведите букву пальцем',
  ExerciseMode.traceFromMemory => 'Напишите букву по памяти',
  ExerciseMode.assemble => 'Соберите слог справа налево',
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
      final revealed = controller.wasWrong.value;
      final isAnswer = index == exercise.answerIndex;

      // После ошибки верный ответ подсвечивается всегда, а выбранный
      // неверный — красным: человек должен увидеть, что именно перепутал.
      final color = switch ((revealed, isAnswer, selected)) {
        (true, true, _) => UIColors.accent,
        (true, false, true) => UIColors.coral,
        _ => UIColors.orange,
      };

      final byName = exercise.mode == ExerciseMode.nameToForm;
      return AnswerOption(
        selected: selected || (revealed && isAnswer),
        accent: color,
        onTap: () => controller.select(index),
        child: byName
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
        borderSide: const BorderSide(color: UIColors.secondary1),
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

class _GlyphCard extends StatelessWidget {
  const _GlyphCard({required this.atom, this.big = false});

  final Atom atom;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: big ? 180 : 120,
      decoration: SquircleBorders.squircleBorder(
        color: UIColors.cardBackground,
        borderRadius: 28,
      ),
      child: Center(
        child: _Glyph(atom: atom, size: big ? 96 : 56),
      ),
    );
  }
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
    final introduced = controller.introAtoms;

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
