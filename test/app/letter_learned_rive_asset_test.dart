import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

// Проверяет, что экспортированный .riv загружается с нужной моделью данных:
// иначе поп-ап незаметно покажет запасной SVG.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('орнамент Rive загружается с моделью данных', (tester) async {
    final loader = rive.FileLoader.fromAsset(
      'assets/rive/animated_shape_1.riv',
      riveFactory: rive.Factory.flutter,
    );
    addTearDown(loader.dispose);

    final file = await tester.runAsync(loader.file);
    expect(file, isNotNull);
    final artboard = file!.defaultArtboard();
    expect(artboard, isNotNull);
    final instance = file.createDefaultViewModelInstance(artboard!);
    addTearDown(() => instance?.dispose());
    expect(instance, isNotNull);
    expect(artboard.defaultStateMachine(), isNotNull);

    final controller = rive.RiveWidgetController(file);
    addTearDown(controller.dispose);
    controller.dataBind(const rive.AutoBind());
    controller.advance(0);
    expect(
      controller.advance(1 / 60),
      isTrue,
      reason: 'state machine должна запросить следующий кадр анимации',
    );
  });
}
