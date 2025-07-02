import 'package:my_app_template/app/resources/ui_resources.dart';
import 'package:flutter/widgets.dart';

class UITextStyles {
  static const pageTitle = TextStyle(
    color: UIColors.text,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    fontFamily: 'Gilroy',
  );
  static const pageTitleSemibold = TextStyle(
    color: UIColors.text,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    fontFamily: 'Gilroy',
  );

  static const buttonTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: UIColors.white,
    fontFamily: 'Gilroy',
  );

  static const regularText = TextStyle(
    color: UIColors.white,
    fontSize: 17,
    fontFamily: 'Gilroy',
  );

  static const regularTextDark = TextStyle(
    color: UIColors.black,
    fontSize: 17,
    fontFamily: 'Gilroy',
  );
  static const semiboldText = TextStyle(
    color: UIColors.white,
    fontWeight: FontWeight.w600,
    fontFamily: 'Gilroy',
  );

  static const regular17 = TextStyle(
    color: UIColors.text,
    fontFamily: 'Gilroy',
    fontSize: 17,
  );
  static const semibold17 = TextStyle(
    color: UIColors.text,
    fontFamily: 'Gilroy',
    fontWeight: FontWeight.w700,
    fontSize: 17,
  );
}
