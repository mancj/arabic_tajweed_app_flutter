import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Защищает границу запуска приложения: отключение и технические пропуски
/// действуют в следующих занятиях, но не переживают перезапуск.
void main() {
  late PronunciationPreference preference;
  late SharedPreferences storage;
  late SharedPreferenceManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await SharedPreferences.getInstance();
    manager = SharedPreferenceManager(storage);
    preference = PronunciationPreference(manager);
  });

  test('технический сбой отключает голос в двух разных сессиях', () async {
    expect(
      await preference.recordSkip(
        sessionId: 3,
        failure: PronunciationFailureKind.serviceUnavailable,
      ),
      isFalse,
    );
    expect(
      await preference.recordSkip(
        sessionId: 3,
        failure: PronunciationFailureKind.recordingFailed,
      ),
      isFalse,
    );
    expect(
      await preference.recordSkip(
        sessionId: 4,
        failure: PronunciationFailureKind.serviceUnavailable,
      ),
      isTrue,
    );
    expect(preference.isDisabled, isTrue);
  });

  test('голосовые занятия получают отдельные номера внутри запуска', () async {
    expect(await preference.beginSession(), 1);
    expect(await PronunciationPreference(manager).beginSession(), 2);
  });

  test('запрет микрофона отключает голос сразу', () async {
    expect(
      await preference.recordSkip(
        sessionId: 1,
        failure: PronunciationFailureKind.microphoneDenied,
      ),
      isTrue,
    );
    expect(preference.isDisabled, isTrue);
  });

  test('явный отказ отключает голос без технической ошибки', () async {
    expect(
      await preference.recordSkip(sessionId: 1, explicitOptOut: true),
      isTrue,
    );
    expect(preference.isDisabled, isTrue);
  });

  test('повторное включение очищает историю сбоев', () async {
    await preference.recordSkip(
      sessionId: 1,
      failure: PronunciationFailureKind.serviceUnavailable,
    );
    await preference.disable();
    await preference.enable();

    expect(preference.isDisabled, isFalse);
    expect(
      await preference.recordSkip(
        sessionId: 2,
        failure: PronunciationFailureKind.serviceUnavailable,
      ),
      isFalse,
    );
  });

  test('отключение действует для всех экранов до перезапуска', () async {
    await preference.disable();
    expect(PronunciationPreference(manager).isDisabled, isTrue);

    final restarted = PronunciationPreference(SharedPreferenceManager(storage));
    expect(restarted.isDisabled, isFalse);
  });

  test('новый запуск забывает прежние технические пропуски', () async {
    expect(
      await preference.recordSkip(
        sessionId: 1,
        failure: PronunciationFailureKind.recordingFailed,
      ),
      isFalse,
    );

    final restarted = PronunciationPreference(SharedPreferenceManager(storage));
    expect(await restarted.beginSession(), 1);
    expect(
      await restarted.recordSkip(
        sessionId: 1,
        failure: PronunciationFailureKind.serviceUnavailable,
      ),
      isFalse,
    );
    expect(restarted.isDisabled, isFalse);
  });

  test('старое сохранённое отключение больше не учитывается', () async {
    SharedPreferences.setMockInitialValues({
      'pronunciationDisabled': true,
      'pronunciationTechnicalSkipSessions': ['1'],
    });
    final restarted = PronunciationPreference(
      SharedPreferenceManager(await SharedPreferences.getInstance()),
    );
    expect(restarted.isDisabled, isFalse);
    expect(
      await restarted.recordSkip(
        sessionId: 1,
        failure: PronunciationFailureKind.recordingFailed,
      ),
      isFalse,
    );
  });
}
