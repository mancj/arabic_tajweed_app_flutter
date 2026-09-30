import 'shared_preference_manager.dart';

/// Почему голосовое задание нельзя выполнить. Неверно названная буква сюда
/// не попадает: это учебная ошибка, а не недоступность функции.
enum PronunciationFailureKind {
  microphoneDenied,
  recordingFailed,
  serviceUnavailable,
}

/// Помнит выбор до перезапуска приложения и отличает повторный тап в одном
/// занятии от технической проблемы в разных занятиях.
class PronunciationPreference {
  PronunciationPreference(this._preferences);

  static const technicalSkipSessionsBeforeDisable = 2;

  final SharedPreferenceManager _preferences;

  bool get isDisabled => _preferences.pronunciationDisabledForRun;

  /// Отдельный номер нужен, потому что занятия без записи в журнале прогресса
  /// внутри одного запуска могут получить одинаковый sessionId.
  Future<int> beginSession() async {
    return ++_preferences.pronunciationSessionCounterForRun;
  }

  Future<bool> recordSkip({
    required int sessionId,
    PronunciationFailureKind? failure,
    bool explicitOptOut = false,
  }) async {
    if (isDisabled) return true;
    if (explicitOptOut ||
        failure == PronunciationFailureKind.microphoneDenied) {
      await disable();
      return true;
    }
    if (failure == null) return false;

    final sessions = _preferences.pronunciationTechnicalSkipSessionsForRun;
    sessions.add(sessionId);
    if (sessions.length >= technicalSkipSessionsBeforeDisable) {
      await disable();
      return true;
    }
    return false;
  }

  Future<void> disable() async {
    _preferences.pronunciationDisabledForRun = true;
  }

  Future<void> enable() async {
    _preferences.pronunciationDisabledForRun = false;
    _preferences.pronunciationTechnicalSkipSessionsForRun.clear();
  }
}
