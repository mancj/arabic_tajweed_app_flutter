// Закрытие диалога адреса не должно уничтожать TextEditingController,
// пока поле ещё используется во время анимации и скрытия клавиатуры.
import 'package:arabic_tajweed_app/app/pages/debug/server_url_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final save in [true, false]) {
    testWidgets('server URL dialog closes safely: save=$save', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const ServerUrlDialog(
                      initialUrl: 'http://old-host:9223',
                    ),
                  );
                },
                child: const Text('Адрес'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Адрес'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '127.0.0.1:9223');
      await tester.tap(find.text(save ? 'Сохранить' : 'Отмена'));
      // Клавиатура меняет MediaQuery ещё до окончания закрытия диалога.
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(result, save ? '127.0.0.1:9223' : isNull);
      expect(find.byType(ServerUrlDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
