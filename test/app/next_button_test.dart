// Защищает платформенное оформление и запрет перехода отключённой кнопкой:
// правки общего NextButton не должны менять Android или включать переход на iOS.
import 'package:arabic_tajweed_app/app/widgets/inner_shadow.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: оформление и отключение перехода',
      (tester) async {
        var taps = 0;
        Future<void> showButton(bool enabled) => tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: NextButton(
                    title: 'Далее',
                    subtitle: 'Следующий шаг',
                    enabled: enabled,
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
        await showButton(true);
        expect(
          find.byType(GlassButton),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(InnerShadows),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        expect(tester.getSize(find.byType(NextButton)), const Size(320, 56));
        await tester.tap(find.text('Далее'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        await showButton(false);
        await tester.tap(find.text('Далее'));
        await tester.pumpAndSettle();
        expect(taps, 1);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
