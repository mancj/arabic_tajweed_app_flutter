// ignore_for_file: non_constant_identifier_names

class UISVGAssets {
  static final search = _path("search");
  static final solarRouteLinear = _path("solar--route-linear");
  static final reiconRouteSquareFilled = _path("reicon--route-square-filled");
  static final hugeiconsRoad01 = _path("hugeicons--road-01");

  // Экран буквы алфавита.
  static final letterGuides = _path("letter_guides");
  static final letterFormStroke = _path("letter_form_stroke");
  static final waveform = _path("waveform");
  static final backButton = _path("back_button");

  // Экран с заданием.
  static final dashedDivider = _path("dashed_divider");
  static final questionMark = _path("question_mark");

  // Экран обводки буквы.
  static final handDraw = _path("hand_draw");

  static String _path(String svgPath) {
    return "assets/svg/$svgPath.svg";
  }
}
