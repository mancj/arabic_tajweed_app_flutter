import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';

/// Строит слои [LetterCard] по коэффициенту масштаба [k].
///
/// Возвращает детей [Stack]: содержимое карточек разложено по макетным
/// координатам через [Positioned].
typedef LetterCardBuilder =
    List<Widget> Function(BuildContext context, double k);

/// Крупная карточка буквы с прописной сеткой: общий каркас экранов
/// «знакомство с буквой» и «обводка».
///
/// Внутренняя раскладка у таких карточек фиксированная, поэтому содержимое
/// верстается в макетных координатах и масштабируется от [designWidth]: так
/// пропорции сохраняются на экранах уже, чем 440pt, под которые нарисован
/// макет. Коэффициент приходит в [builder] — на него множатся все размеры.
class LetterCard extends StatelessWidget {
  /// Ширина карточки в макете.
  static const designWidth = 401.0;

  /// Высота карточки в макете; итоговая высота — [designHeight] * k.
  final double designHeight;

  final LetterCardBuilder builder;

  const LetterCard({
    required this.designHeight,
    required this.builder,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final k = constraints.maxWidth / designWidth;

        return Container(
          height: designHeight * k,
          decoration: SquircleBorders.squircleBorder(
            color: UIColors.backgroundShapes1,
            borderRadius: 30 * k,
            borderSide: BorderSide(color: UIColors.secondary1),
            shadows: [
              BoxShadow(
                color: UIColors.shadows,
                offset: Offset(0, 4),
                blurRadius: 3,
              ),
            ],
          ),
          child: Stack(children: builder(context, k)),
        );
      },
    );
  }
}

/// Сетка прописи внутри [LetterCard]: рамка с базовыми линиями, по которым
/// поставлена буква. Размеры — макетные, множатся на масштаб карточки.
class LetterGuides extends StatelessWidget {
  /// Размеры сетки в макете.
  static const designWidth = 369.0;
  static const designHeight = 200.0;

  /// Масштаб карточки, в которой лежит сетка.
  final double k;

  const LetterGuides({required this.k, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: designWidth * k,
      height: designHeight * k,
      child: SvgPicture.asset(UISVGAssets.letterGuides, fit: BoxFit.fill),
    );
  }
}
