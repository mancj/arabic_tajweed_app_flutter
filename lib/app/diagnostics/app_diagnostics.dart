import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Ошибки приложения доступны в меню отладки даже без подключения к консоли.
final class AppDiagnostics {
  AppDiagnostics._();

  static final Talker talker = TalkerFlutter.init(
    settings: TalkerSettings(maxHistoryItems: 300, useConsoleLogs: false),
  );

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      talker.handle(
        details.exception,
        details.stack,
        'Flutter${details.library == null ? '' : ' · ${details.library}'}',
      );
      previousFlutterHandler?.call(details);
    };

    final dispatcher = PlatformDispatcher.instance;
    final previousPlatformHandler = dispatcher.onError;
    dispatcher.onError = (error, stackTrace) {
      talker.handle(error, stackTrace, 'Необработанная ошибка');
      return previousPlatformHandler?.call(error, stackTrace) ?? false;
    };
  }
}
