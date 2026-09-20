import 'package:arabic_tajweed_app/app/widgets/ui_kit/badge_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:rive/rive.dart' as rive;

import '../../../domain/atom.dart';
import '../../resources/ui_resources.dart';
import '../margin.dart';
import 'next_button.dart';

const double _defaultAnimationSpeed = 3;

/// Показывает награду за изученную букву. Анимация запускается при каждом открытии.
Future<void> showLetterLearnedPopup(
  BuildContext context, {
  required Atom atom,
  Color? ornamentColor,
  double animationSpeed = _defaultAnimationSpeed,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => Dialog(
    backgroundColor: UIColors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: SingleChildScrollView(
      child: Center(
        child: LetterLearnedPopup(
          atom: atom,
          ornamentColor: ornamentColor,
          animationSpeed: animationSpeed,
        ),
      ),
    ),
  ),
);

/// Карточка из макета: Flutter рисует содержимое, Rive — только орнамент.
class LetterLearnedPopup extends StatelessWidget {
  const LetterLearnedPopup({
    required this.atom,
    this.ornamentColor,
    this.animationSpeed = _defaultAnimationSpeed,
    super.key,
  }) : assert(animationSpeed > 0);

  final Atom atom;
  final Color? ornamentColor;

  /// Множитель скорости всех анимаций: 1 — исходная, 3 — втрое быстрее.
  /// Должен быть больше нуля; 0 означает остановку, а не мгновенное завершение.
  final double animationSpeed;

  @override
  Widget build(BuildContext context) {
    // Подписка на системную тему перестраивает и уже открытый поп-ап.
    MediaQuery.platformBrightnessOf(context);
    final color = ornamentColor ?? UIColors.ornamentStroke;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UIColors.cardBackground,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: UIColors.shadows,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Margin.vertical(32),
              Align(
                child: SizedBox(
                  width: 204,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: _AnimatedOrnament(
                          color: color,
                          speed: animationSpeed,
                        ),
                      ),
                      Text(
                            atom.display,
                            textDirection: TextDirection.rtl,
                            style: UITextStyles.dgFasehRegular(114, height: 1),
                          )
                          .animate()
                          .fadeIn(delay: .8.seconds, duration: 500.milliseconds)
                          .scaleXY(
                            begin: .7,
                            duration: 500.milliseconds,
                            curve: Curves.easeInOutBack,
                          ),
                    ],
                  ),
                ),
              ),
              BadgeLabel(
                    text: 'Изучено',
                    color: UIColors.primary,
                    textColor: UIColors.primaryButtonText,
                  )
                  .animate()
                  .fadeIn(delay: .1.seconds, duration: 500.milliseconds)
                  .then()
                  .shimmer(),
              const Margin.vertical(24),
              Text(
                'Буква изучена',
                textAlign: TextAlign.center,
                style: UITextStyles.semibold22,
              ).animate().fadeIn(delay: .3.seconds, duration: 500.milliseconds),
              const Margin.vertical(4),
              Align(
                child: Text(
                  'Вы успешно выучили букву ${atom.label}.\n'
                  'Помните, что каждая выученная буква '
                  'приближает вас к чтению Корана.',
                  textAlign: TextAlign.center,
                  style: UITextStyles.regular16.copyWith(
                    color: UIColors.text,
                  ),
                ),
              ).animate().fadeIn(delay: .5.seconds, duration: 500.milliseconds),
              const Margin.vertical(8),
              Text(
                'Буква ${atom.label} будет и дальше встречаться в упражнениях, но реже других. Так вы сможете лучше закрепить её в памяти.',
                textAlign: TextAlign.center,
                style: UITextStyles.monoRegular12.copyWith(
                  color: UIColors.secondary2,
                ),
              ).animate().fadeIn(delay: .7.seconds, duration: 500.milliseconds),
              const Margin.vertical(32),
              NextButton(
                title: 'Закрыть',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DashedCardBorder(UIColors.ornamentStroke),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedOrnament extends StatefulWidget {
  const _AnimatedOrnament({required this.color, required this.speed});

  final Color color;
  final double speed;

  @override
  State<_AnimatedOrnament> createState() => _AnimatedOrnamentState();
}

class _AnimatedOrnamentState extends State<_AnimatedOrnament> {
  late final rive.FileLoader _loader = rive.FileLoader.fromAsset(
    'assets/rive/animated_shape_1.riv',
    riveFactory: rive.Factory.flutter,
  );
  _SpeedRiveWidgetController? _controller;

  @override
  void didUpdateWidget(covariant _AnimatedOrnament oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller?.speed = widget.speed;
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ColorFiltered(
      colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      child: rive.RiveWidgetBuilder(
        fileLoader: _loader,
        controller: (file) =>
            _controller = _SpeedRiveWidgetController(file, speed: widget.speed),
        builder: (context, state) => switch (state) {
          rive.RiveLoading() => const SizedBox.expand(),
          rive.RiveLoaded() => rive.RiveWidget(
            controller: state.controller,
            fit: rive.Fit.contain,
          ),
          rive.RiveFailed() => SvgPicture.asset(
            'assets/svg/letter_learned_ornament.svg',
            fit: BoxFit.contain,
          ),
        },
      ),
    ),
  );
}

final class _SpeedRiveWidgetController extends rive.RiveWidgetController {
  _SpeedRiveWidgetController(super.file, {required this.speed});

  double speed;

  @override
  bool advance(double elapsedSeconds) => super.advance(elapsedSeconds * speed);
}

class _DashedCardBorder extends CustomPainter {
  const _DashedCardBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(5.5, 5.5, size.width - 12, size.height - 12);
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(25)));
    canvas.drawPath(
      dashPath(outline, dashArray: CircularIntervalList<double>([4, 4])),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedCardBorder oldDelegate) =>
      oldDelegate.color != color;
}
