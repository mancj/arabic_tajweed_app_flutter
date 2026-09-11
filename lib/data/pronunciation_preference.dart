import 'shared_preference_manager.dart';

/// Почему голосовое задание нельзя выполнить. Неверно названная буква сюда
/// не попадает: это учебная ошибка, а не недоступность функции.
enum PronunciationFailureKind {
  microphoneDenied,
  recordingFailed,
  serviceUnavailable,
}

/// Сохраняет выбор человека и отличает повторный тап в одном занятии от
/// технической проблемы, которая повторилась в разных занятиях.
class PronunciationPreference {
  PronunciationPreference(this._preferences);

  static const technicalSkipSessionsBeforeDisable = 2;

  final SharedPreferenceManager _preferences;

  bool get isDisabled => _preferences.pronunciationDisabled.get() ?? false;

  /// Отдельный номер нужен, потому что занятие без единой записи в журнале
  /// прогресса при следующем запуске получило бы тот же sessionId.
  Future<int> beginSession() async {
    final next = (_preferences.pronunciationSessionCounter.get() ?? 0) + 1;
    await _preferences.pronunciationSessionCounter.set(next);
    return next;
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

    final sessions = {
      ..._preferences.pronunciationTechnicalSkipSessions.get(),
      '$sessionId',
    };
    await _preferences.pronunciationTechnicalSkipSessions.set(
      sessions.toList(),
    );
    if (sessions.length >= technicalSkipSessionsBeforeDisable) {
      await disable();
      return true;
    }
    return false;
  }

  Future<void> disable() => _preferences.pronunciationDisabled.set(true);

  Future<void> enable() async {
    await _preferences.pronunciationDisabled.set(false);
    await _preferences.pronunciationTechnicalSkipSessions.set([]);
  }
}
