// Регрессионная проверка: высота шапки уже входит в headerZone. Если добавить
// её к блюру повторно, на мобильном Web размоется заголовок страницы.

import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('верхний блюр заканчивается сразу под шапкой', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
        child: MaterialApp(
          home: AppScaffold(
            showBackButton: false,
            builder: (_, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );

    final effect = tester.widget<GlassScrollEdgeEffect>(
      find.byType(GlassScrollEdgeEffect),
    );

    expect(effect.topFadeHeight, 47 + 16 + 46 + 16);
  });
}
