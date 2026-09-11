import 'package:arabic_tajweed_app/data/pronunciation_preference.dart';
import 'package:arabic_tajweed_app/data/shared_preference_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Защищает границу между временным сбоем и сохранённым отказом от голоса:
/// повторные нажатия в одном уроке не должны навсегда менять программу.
void main() {
  late PronunciationPreference preference;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preference = PronunciationPreference(
      SharedPreferenceManager(await SharedPreferences.getInstance()),
    );
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

  test('голосовые сессии получают отдельные устойчивые номера', () async {
    expect(await preference.beginSession(), 1);
    expect(await preference.beginSession(), 2);
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
}
