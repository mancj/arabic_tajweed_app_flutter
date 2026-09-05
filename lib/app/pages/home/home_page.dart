import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/drawing/drawing_canvas.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/lesson_progress_bar.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/letter_card.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/segmented_tabs.dart';

import 'home_page_controller.dart';

export 'home_page_binding.dart';
export 'home_page_controller.dart';

/// Экран обводки буквы (макет Tajweed, node 12:293).
///
/// Каркас, полоса прогресса и кнопка «Далее» те же, что на экране знакомства
/// с буквой; отличается только карточка — вместо готового глифа в ней холст,
/// на котором букву обводят по бледной подсказке или рисуют по памяти.
class HomePage extends GetView<HomeController> {
  static const routeName = '/home';

  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Алфавит',
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: Column(
          children: [
            Obx(() => LessonProgressBar(value: controller.progress)),
            const Margin.vertical(12),
            const _ModeTabs(),
            const Margin.vertical(16),
            const _TracingCard(),
            const Margin.vertical(12),
            const _LetterTabs(),
            const Margin.vertical(8),
            const _FormTabs(),
            const Margin.vertical(12),
            const _CanvasActions(),
          ],
        ),
      ),
    );
  }
}

/// Переключатель режима: обводить бледную букву или рисовать её по памяти.
class _ModeTabs extends GetView<HomeController> {
  const _ModeTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SegmentedTabs(
        labels: HomeController.modeTitles,
        selected: HomeController.modes.indexOf(controller.mode.value),
        onChanged: (index) => controller.setMode(HomeController.modes[index]),
      ),
    );
  }
}

/// Выбор буквы: все 28 в порядке курикулума. В дорожку они не помещаются,
/// поэтому сегменты фиксированной ширины, а сама дорожка прокручивается.
class _LetterTabs extends GetView<HomeController> {
  const _LetterTabs();

  static const _style = TextStyle(
    fontFamily: UITextStyles.fontScheherazadeNew,
    fontSize: 22,
    color: UIColors.tealDark,
  );

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SegmentedTabs(
        labels: [for (final item in controller.letters) item.glyph],
        selected: controller.index.value,
        onChanged: controller.setLetter,
        style: _style,
        segmentWidth: 48,
      ),
    );
  }
}

/// Форма выбранной буквы. У ا د ذ ر ز و форм две вместо четырёх, поэтому
/// список свой на каждую букву.
class _FormTabs extends GetView<HomeController> {
  const _FormTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final forms = controller.current?.forms ?? const [];
      if (forms.length < 2) return const SizedBox.shrink();

      return SegmentedTabs(
        labels: [
          for (final form in forms) HomeController.formTitles[form.form]!,
        ],
        selected: controller.formIndex.value,
        onChanged: controller.setForm,
      );
    });
  }
}

/// Карточка обводки: подсказка сверху, сетка прописи с холстом и название
/// буквы снизу.
class _TracingCard extends GetView<HomeController> {
  /// Высота карточки в макете.
  static const _height = 410.0;

  /// Холст выше сетки: у букв набора общий квадратный кадр (viewBox 329),
  /// в него заложен запас под верхние и нижние диакритики. По высоте сетки
  /// такой кадр ужал бы саму букву вдвое против макета, поэтому в холст
  /// вписывается кадр целиком, а сетка остаётся фоном внутри него.
  static const _canvasTop = 18.0;
  static const _canvasHeight = 329.0;

  const _TracingCard();

  @override
  Widget build(BuildContext context) {
    return LetterCard(
      designHeight: _height,
      builder: (context, k) => [
        Positioned(
          top: 104 * k,
          left: 0,
          right: 0,
          height: LetterGuides.designHeight * k,
          child: Center(child: LetterGuides(k: k)),
        ),
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
                  matcher: HomeController.matcher,
                  mode: controller.mode.value,
                  placeholder: controller.shape.value,
                  // Перо берётся из фигуры: тогда обводка ложится ровно
                  // в толщину подсказки.
                  color: UIColors.tealDark,
                  placeholderColor: UIColors.letterGhost,
                  placeholderPadding: 0,
                  onProgress: controller.onProgress,
                  onChecked: controller.onChecked,
                ),
              ),
            ),
          ),
        ),
        // Подсказка лежит поверх холста, но не отбирает у него касания:
        // кадр буквы заходит выше сетки и достаёт до строки подсказки.
        Positioned(
          top: 32 * k,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Obx(() => _Hint(text: controller.hint.value, k: k)),
          ),
        ),
        Positioned(
          top: 361 * k,
          left: 0,
          right: 0,
          child: Obx(
            () => Text(
              controller.letter?.name ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: UITextStyles.fontOnest,
                fontWeight: FontWeight.w600,
                fontSize: 22 * k,
                color: UIColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Строка-подсказка с иконкой руки над сеткой.
class _Hint extends StatelessWidget {
  final String text;
  final double k;

  const _Hint({required this.text, required this.k});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(UISVGAssets.handDraw, width: 16 * k, height: 16 * k),
        Margin.horizontal(4 * k),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: UITextStyles.fontOnest,
              fontWeight: FontWeight.w500,
              fontSize: 15 * k,
              color: UIColors.tealDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// Отмена, очистка и проверка холста. Части засчитываются сами, сразу
/// после штриха, — «Проверить» здесь только чтобы увидеть разбор попытки.
class _CanvasActions extends GetView<HomeController> {
  const _CanvasActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconAction(
          icon: Icons.undo_rounded,
          semanticLabel: 'Отменить',
          onTap: controller.undo,
        ),
        const Margin.horizontal(8),
        _IconAction(
          icon: Icons.close_rounded,
          semanticLabel: 'Очистить',
          onTap: controller.clear,
        ),
        const Margin.horizontal(8),
        Expanded(child: _CheckButton(onTap: controller.check)),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Обработчик уходит внутрь [CircleButton]: он сам жестовый детектор,
    // и обёртка снаружи тапа не увидит — внутренний выигрывает арену.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: CircleButton(
        onTap: onTap,
        size: 44,
        child: Icon(icon, size: 20, color: UIColors.white),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CheckButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppGestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: SquircleBorders.squircleBorder(
          color: UIColors.white,
          borderRadius: 16,
          borderSide: const BorderSide(color: UIColors.cardBorder, width: 0.6),
          shadows: const [
            BoxShadow(
              color: UIColors.cardShadowSoft,
              offset: Offset(0, 3),
              blurRadius: 1.5,
            ),
          ],
        ),
        child: const Text(
          'Проверить',
          style: TextStyle(
            fontFamily: UITextStyles.fontOnest,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: UIColors.tealDark,
          ),
        ),
      ),
    );
  }
}
