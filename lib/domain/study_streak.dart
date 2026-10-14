/// Последовательные местные календарные дни реальной работы с материалом.
class StudyStreak {
  const StudyStreak._({required this.days, this.startedOn});

  factory StudyStreak.fromActivityDays(
    Iterable<DateTime> activityDays, {
    required DateTime today,
  }) {
    final days = activityDays.map(_localDay).toSet();
    var day = _localDay(today);
    DateTime? start;
    var count = 0;
    while (days.contains(day)) {
      start = day;
      count++;
      // Календарный день может длиться 23 или 25 часов при смене времени.
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return StudyStreak._(days: count, startedOn: start);
  }

  final int days;
  final DateTime? startedOn;

  /// Семь местных календарных дней до выбранной даты включительно.
  /// Окно серии не привязано к понедельнику и не содержит будущих дней.
  static List<DateTime> weekEndingOn(DateTime at) {
    final end = _localDay(at);
    return List.generate(
      7,
      (index) => DateTime(end.year, end.month, end.day - 6 + index),
    );
  }

  DateTime? get weeklyAchievementOn {
    final start = startedOn;
    return days >= 7 && start != null
        ? DateTime(start.year, start.month, start.day + 6)
        : null;
  }

  bool needsWeeklyCelebration({DateTime? celebratedStart}) =>
      weeklyAchievementOn != null &&
      (celebratedStart == null || startedOn != _localDay(celebratedStart));

  static DateTime _localDay(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
