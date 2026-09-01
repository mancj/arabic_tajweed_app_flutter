// ignore_for_file: non_constant_identifier_names

class UISVGAssets {
  static final search = _path("search");

  // Экран буквы алфавита.
  static final letterGuides = _path("letter_guides");
  static final letterFormStroke = _path("letter_form_stroke");
  static final waveform = _path("waveform");
  static final backButton = _path("back_button");

  // Экран обводки буквы.
  static final handDraw = _path("hand_draw");

  static String _path(String svgPath) {
    return "assets/svg/$svgPath.svg";
  }
}
