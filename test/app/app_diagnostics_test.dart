import 'package:arabic_tajweed_app/app/diagnostics/app_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Без этого перехвата ошибка виджета в release остаётся серым квадратом,
// а в меню отладки нечего скопировать для выяснения причины.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ошибка Flutter сохраняется вместе со стеком', () {
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = originalHandler);
    AppDiagnostics.install();

    final error = StateError('Rive widget failed');
    final stackTrace = StackTrace.current;
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'widgets',
      ),
    );

    final entry = AppDiagnostics.talker.history.last;
    expect(entry.error, same(error));
    expect(entry.stackTrace, same(stackTrace));
  });
}
