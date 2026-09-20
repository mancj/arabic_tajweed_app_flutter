enum PronunciationDecision { accepted, retry, ignored, wrong }

/// Считает только учебные попытки. Техническое предупреждение не расходует их.
class PronunciationAttempts {
  int count = 1;

  PronunciationDecision evaluate({
    required bool matched,
    required bool hasWarning,
    required int limit,
  }) {
    if (matched) return PronunciationDecision.accepted;
    if (hasWarning) return PronunciationDecision.ignored;
    if (count < limit) {
      count++;
      return PronunciationDecision.retry;
    }
    return PronunciationDecision.wrong;
  }

  void reset() => count = 1;
}
