import 'microphone_permission.dart';
import 'shared_preference_manager.dart';

/// Почему голосовое задание нельзя выполнить. Неверно названная буква сюда
/// не попадает: это учебная ошибка, а не недоступность функции.
enum PronunciationFailureKind {
  microphoneDenied,
  recordingFailed,
  serviceUnavailable,
}

/// Любой отказ от голоса действует до перезапуска приложения. Постоянный
/// запрет микрофона хранит система, его проверяем заново при запуске.
class PronunciationPreference {
  PronunciationPreference(this._preferences);

  final SharedPreferenceManager _preferences;

  bool get isDisabled => _preferences.pronunciationDisabledForRun;

  /// Без запроса разрешения: первый запуск не открывает системный диалог.
  Future<void> checkMicrophoneAccess({
    MicrophonePermission permission = const MicrophonePermission(),
  }) async {
    if (await permission.isPermanentlyDenied()) await disable();
  }

  Future<void> disable() async {
    _preferences.pronunciationDisabledForRun = true;
  }

  Future<void> enable() async {
    _preferences.pronunciationDisabledForRun = false;
  }
}
