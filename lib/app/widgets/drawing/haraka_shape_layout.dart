import 'dart:ui';

import 'tracing_shape.dart';

/// Ставит огласовку относительно реальных границ конкретной буквы.
///
/// SVG всего набора используют общий viewBox, поэтому перенос сохраняет одну
/// систему координат для фона, подсказки, проверки штрихов и анимации.
class HarakaShapeLayout {
  HarakaShapeLayout._();

  static const gap = 12.0;

  static TracingShape place({
    required TracingShape haraka,
    required TracingShape letter,
  }) {
    final mark = haraka.bounds;
    final base = letter.bounds;
    final below = haraka.id.split('/').last == 'kasra';
    final offset = Offset(
      base.center.dx - mark.center.dx,
      below ? base.bottom + gap - mark.top : base.top - gap - mark.bottom,
    );
    // У части букв кадр 329×329, у огласовок — 329×323. Фон и знак
    // должны вписываться в один кадр, иначе знак съезжает к краю холста.
    return haraka.translated(offset, viewBox: letter.viewBox);
  }
}
