import 'dart:ui';

import 'package:arabic_tajweed_app/app/widgets/drawing/tracing_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Алиф — почти вертикальная линия: ширина эталона близка к нулю, а ширина
/// нарисованной линии зависит от наклона руки. Раньше подгонка размера брала
/// среднее двух осей и от небольшого наклона раздувала букву вдвое — на
/// холсте изредка появлялся алиф выше карточки. У тонкой фигуры масштаб
/// считается только по длинной оси.
void main() {
  TracingAlignment? fit(Rect from, Rect to) =>
      TracingAlignment.fit(from: from, to: to, minScale: .4, maxScale: 3);

  test('наклон тонкой буквы не меняет её масштаб', () {
    const alif = Rect.fromLTWH(0, 0, 12, 300);
    for (final width in [1.0, 4.0, 20.0, 40.0]) {
      final alignment = fit(Rect.fromLTWH(0, 0, width, 300), alif)!;
      expect(
        alignment.scale,
        closeTo(1, 0.01),
        reason: 'линия шириной $width не должна менять масштаб',
      );
    }
  });

  test('тонкая буква масштабируется по длине', () {
    const alif = Rect.fromLTWH(0, 0, 12, 300);
    final alignment = fit(const Rect.fromLTWH(0, 0, 8, 150), alif)!;
    expect(alignment.scale, closeTo(2, 0.01));
  });

  test('у широкой буквы масштаб учитывает обе оси', () {
    final alignment = fit(
      const Rect.fromLTWH(0, 0, 200, 100),
      const Rect.fromLTWH(0, 0, 100, 50),
    )!;
    expect(alignment.scale, closeTo(0.5, 0.01));
  });
}
