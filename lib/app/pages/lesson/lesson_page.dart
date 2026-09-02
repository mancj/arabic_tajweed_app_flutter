import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
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
        final exercise = controller.current;
        // У заглушки нет своей проверки — обе ветки задаёт человек.
        // TODO(stub): убрать вторую кнопку вместе с заглушками.
        if (exercise != null &&
            !exercise.isChoice &&
            !controller.wasWrong.value) {
          return Row(
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
          );
        }
        return NextButton(
          title: controller.wasWrong.value ? 'Ясно' : 'Ответить',
          enabled: controller.canSubmit,
          onTap: controller.canSubmit ? () => controller.submit() : null,
        );
      }),
      LessonStage.finished => NextButton(title: 'Завершить', onTap: Get.back),
    };
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

class _ExerciseBlock extends GetView<LessonController> {
  const _ExerciseBlock();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final exercise = controller.current;
      if (exercise == null) return const _Centered(child: _Loader());

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

String _promptOf(ExerciseMode mode) => switch (mode) {
  ExerciseMode.formToName => 'Как называется эта буква?',
  ExerciseMode.nameToForm => 'Выберите, как она пишется',
  ExerciseMode.distinguishDots => 'Какая из них — эта буква?',
  ExerciseMode.findInWord => 'Найдите эту букву в слове',
  ExerciseMode.formToPosition => 'Где в слове стоит эта форма?',
  ExerciseMode.soundToLetter => 'Послушайте и выберите букву',
  ExerciseMode.letterToSound => 'Как звучит эта буква?',
  ExerciseMode.trace => 'Обведите букву пальцем',
  ExerciseMode.assemble => 'Соберите слог справа налево',
};

/// Чего не хватает режиму, чтобы работать по-настоящему.
String _stubHintOf(ExerciseMode mode) => switch (mode) {
  ExerciseMode.trace =>
    'Заглушка. Холст обводки уже написан — осталось встроить его сюда '
        'и завести SVG-пути с порядком штрихов, см. SPEC.md §12.',
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
