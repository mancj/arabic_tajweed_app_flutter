import 'dart:math' as math;

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/badge_label.dart';

/// Карточка задания: плашка «Вопрос», формулировка и крупный предмет вопроса
/// на фоне из бледных форм буквы и чертежа её построения.
///
/// Фон разложен по координатам макета и привязан к краям карточки: чертёж
/// и бледные формы уходят за обрез, поэтому важно, где именно они его
/// пересекают.
class QuestionCard extends StatelessWidget {
  /// Высота карточки в макете.
  static const designHeight = 251.0;

  /// Сторона квадрата, в котором экспортирован чертёж.
  static const _decorSide = 414.0;

  final String badge;
  final String question;

  /// Что показывают: глиф буквы или её название — зависит от режима.
  final String subject;

  /// Шрифт [subject]: у арабского глифа он свой.
  final String subjectFont;

  /// Бледные формы той же буквы справа. Без них фон остаётся с чертежом.
  final String? ghost;

  const QuestionCard({
    required this.badge,
    required this.question,
    required this.subject,
    this.subjectFont = UITextStyles.fontScheherazadeNew,
    this.ghost,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const shape = SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius.all(
        SmoothRadius(cornerRadius: 24, cornerSmoothing: 1),
      ),
      side: BorderSide(color: UIColors.white),
    );

    return Container(
      height: designHeight,
      decoration: const ShapeDecoration(
        color: UIColors.questionCardBackground,
        shape: shape,
        shadows: [
          BoxShadow(
            color: UIColors.questionCardShadow,
            offset: Offset(0, 6),
            blurRadius: 4.8,
          ),
        ],
      ),
      // Чертёж уходит за края карточки — в макете он подрезан её формой.
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: shape),
        child: Stack(
          children: [
            _decorArc(),
            _decorRing(),
            if (ghost != null) ..._ghosts(),
            _subject(),
            _header(),
          ],
        ),
      ),
    );
  }

  /// Дуга у левого верхнего угла. Экспортирована обрезанной, поэтому лежит
  /// в квадрате со своими полями — иначе поворот придётся не вокруг центра.
  Widget _decorArc() => Positioned(
    left: -222.26,
    top: -224.26,
    width: _decorSide,
    height: _decorSide,
    child: Transform.rotate(
      angle: 135 * math.pi / 180,
      child: Padding(
        padding: const EdgeInsets.only(left: 37, top: 37.1),
        child: SizedBox(
          width: 376.553,
          height: 339.719,
          child: SvgPicture.asset(
            UISVGAssets.questionDecorArc,
            fit: BoxFit.fill,
          ),
        ),
      ),
    ),
  );

  /// Тот же чертёж целиком — уходит за правый край карточки.
  Widget _decorRing() => Positioned(
    right: -185,
    top: 30,
    width: _decorSide,
    height: _decorSide,
    child: RotatedBox(
      quarterTurns: 3,
      child: SvgPicture.asset(UISVGAssets.questionDecorRing, fit: BoxFit.fill),
    ),
  );

  /// Бледные формы буквы у правого края: крупная уходит за обрез.
  List<Widget> _ghosts() {
    const style = TextStyle(color: UIColors.glyphGhost, height: 1);

    return [
      Positioned(
        right: 16,
        top: 143,
        width: 212,
        height: 135,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            ghost!,
            style: style.copyWith(fontFamily: subjectFont, fontSize: 98.5),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
      Positioned(
        right: 16.118,
        top: 120,
        width: 47.118,
        height: 93,
        child: Center(
          child: Text(
            "ـــ$ghost",
            style: style.copyWith(fontFamily: subjectFont, fontSize: 56.833),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    ];
  }

  Widget _subject() => Positioned(
    left: 16,
    right: 16,
    top: 83,
    height: 135,
    // Название буквы длиннее глифа: макетный кегль ему велик, поэтому
    // текст ужимается до ширины карточки.
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          subject,
          style: TextStyle(
            fontFamily: subjectFont,
            fontSize: 82.5,
            height: 1,
            color: UIColors.black,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    ),
  );

  Widget _header() => Positioned(
    left: 16,
    top: 16,
    right: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BadgeLabel(text: badge, color: UIColors.black),
        const Margin.vertical(8),
        Text(question, style: UITextStyles.cardTitle),
      ],
    ),
  );
}
