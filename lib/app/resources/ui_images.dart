// ignore_for_file: non_constant_identifier_names

import 'package:collection/collection.dart';

class UIImages {
  static final background_shape_1_1 = _png("background_shape_1_1");
  static final background_shape_1_2 = _png("background_shape_1_2");
  static final background_shape_2_1 = _png("background_shape_2_1");
  static final background_shape_2_2 = _png("background_shape_2_2");

  static (String, String) get background_shape_1 =>
      (background_shape_1_1, background_shape_1_2);

  static (String, String) get background_shape_2 =>
      (background_shape_2_1, background_shape_2_2);

  static String _png(String img) {
    return "assets/img/$img.png";
  }
}
