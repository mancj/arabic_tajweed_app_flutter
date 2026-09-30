// Повторный экспорт Rive может убрать нужный артборд, машину состояний
// или зацикливание. Тогда просмотр в меню отладки не загрузится либо замрёт.

import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('орбитальные кольца загружаются и продолжают цикл', (
    tester,
  ) async {
    final loader = rive.FileLoader.fromAsset(
      'assets/rive/orbital_rings.riv',
      riveFactory: rive.Factory.flutter,
    );
    addTearDown(loader.dispose);

    final file = await tester.runAsync(loader.file);
    expect(file, isNotNull);
    final controller = rive.RiveWidgetController(
      file!,
      artboardSelector: const rive.ArtboardNamed('Orbital Rings'),
      stateMachineSelector: const rive.StateMachineNamed('Orbit Player'),
    );
    addTearDown(controller.dispose);

    controller.advance(0);
    for (var frame = 0; frame < 540; frame++) {
      expect(
        controller.advance(1 / 60),
        isTrue,
        reason: 'Анимация должна продолжаться после полного цикла: кадр $frame',
      );
    }
  });
}
