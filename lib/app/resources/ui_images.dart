// ignore_for_file: non_constant_identifier_names

class UIImages {
  static final profileIdentity = _png('profile_identity');

  static final background_shape_1_1 = _png("background_shape_1_1");
  static final background_shape_1_2 = _png("background_shape_1_2");
  static final background_shape_2_1 = _png("background_shape_2_1");
  static final background_shape_2_2 = _png("background_shape_2_2");
  static final background_shape_3_1 = _png("background_shape_3_1");
  static final background_shape_3_2 = _png("background_shape_3_2");

  static (String, String) get background_shape_1 =>
      (background_shape_1_1, background_shape_1_2);

  static (String, String) get background_shape_2 =>
      (background_shape_2_1, background_shape_2_2);

  static (String, String) get background_shape_3 =>
      (background_shape_3_1, background_shape_3_2);

  static String _png(String img) {
    return "assets/img/$img.png";
  }

  static String _jpg(String img) {
    return "assets/img/$img.jpg";
  }
}
