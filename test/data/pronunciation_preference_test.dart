import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отключение общее для экранов, но не сохраняется между запусками.
/// Исключение — подтверждённый системой постоянный запрет микрофона:
/// проверка не запрашивает разрешение и учитывает его выдачу в настройках.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PronunciationPreference preference;
  late SharedPreferences storage;
  late SharedPreferenceManager manager;
  var microphoneStatus = PermissionStatus.granted;
  final permissionCalls = <String>[];
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await SharedPreferences.getInstance();
    manager = SharedPreferenceManager(storage);
    preference = PronunciationPreference(manager);
    microphoneStatus = PermissionStatus.granted;
    permissionCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          permissionCalls.add(call.method);
          expect(call.method, 'checkPermissionStatus');
          expect(call.arguments, Permission.microphone.value);
          return microphoneStatus.index;
        });
  });

  test('голос можно включить в том же запуске', () async {
    await preference.disable();
    await preference.enable();
    expect(preference.isDisabled, isFalse);
  });

  test('отключение действует для всех экранов до перезапуска', () async {
    await preference.disable();
    expect(PronunciationPreference(manager).isDisabled, isTrue);

    final restarted = PronunciationPreference(SharedPreferenceManager(storage));
    await restarted.checkMicrophoneAccess();
    expect(restarted.isDisabled, isFalse);
    expect(storage.getBool('pronunciationDisabled'), isNull);
  });

  for (final status in [
    PermissionStatus.granted,
    PermissionStatus.denied,
    PermissionStatus.restricted,
    PermissionStatus.permanentlyDenied,
  ]) {
    test('при запуске учитывается статус микрофона $status', () async {
      microphoneStatus = status;
      await preference.checkMicrophoneAccess();
      expect(preference.isDisabled, status.isPermanentlyDenied);
      expect(permissionCalls, ['checkPermissionStatus']);
    });
  }

  test('выдача доступа в настройках возвращает голос при запуске', () async {
    microphoneStatus = PermissionStatus.permanentlyDenied;
    await preference.checkMicrophoneAccess();
    expect(preference.isDisabled, isTrue);

    final stillDenied = PronunciationPreference(
      SharedPreferenceManager(storage),
    );
    await stillDenied.checkMicrophoneAccess();
    expect(stillDenied.isDisabled, isTrue);

    microphoneStatus = PermissionStatus.granted;
    final allowed = PronunciationPreference(SharedPreferenceManager(storage));
    await allowed.checkMicrophoneAccess();
    expect(allowed.isDisabled, isFalse);
  });

  test(
    'проверка доступа в том же запуске не отменяет выбор пропуска',
    () async {
      await preference.disable();
      await preference.checkMicrophoneAccess();
      expect(preference.isDisabled, isTrue);
    },
  );

  test('старое сохранённое отключение больше не учитывается', () async {
    SharedPreferences.setMockInitialValues({
      'pronunciationDisabled': true,
      'pronunciationTechnicalSkipSessions': ['1'],
    });
    final restarted = PronunciationPreference(
      SharedPreferenceManager(await SharedPreferences.getInstance()),
    );
    await restarted.checkMicrophoneAccess();
    expect(restarted.isDisabled, isFalse);
  });
}
