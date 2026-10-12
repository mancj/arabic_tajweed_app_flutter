// Достижение требует реальных последовательных календарных дней: несколько
// ответов в один день, смена месяца, года или летнего времени не меняют срок.
// Длинная серия поздравляется один раз, новая после пропуска — снова.
import 'package:arabic_tajweed_app/domain/study_streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('пропуск дня разрывает серию, повторы дня её не удлиняют', () {
    final today = DateTime(2026, 10, 11, 18);
    final streak = StudyStreak.fromActivityDays([
      DateTime(2026, 10, 4),
      DateTime(2026, 10, 6),
      for (var day = 8; day <= 11; day++) DateTime(2026, 10, day),
      DateTime(2026, 10, 11, 10),
      DateTime(2026, 10, 12),
    ], today: today);
    expect(streak.days, 4);
    expect(streak.needsWeeklyCelebration(), isFalse);
  });

  test('неделя сохраняется через Новый год и смену местного времени', () {
    // При TZ=America/New_York две даты проверяют неделю из 23- и 25-часовых дней.
    for (final today in [
      DateTime(2027, 1, 3),
      DateTime(2026, 3, 11),
      DateTime(2026, 11, 4),
    ]) {
      final streak = StudyStreak.fromActivityDays([
        for (var offset = 0; offset < 7; offset++)
          DateTime(today.year, today.month, today.day - offset, 14).toUtc(),
      ], today: today);
      expect(streak.days, 7);
      expect(streak.weeklyAchievementOn, today);
      expect(streak.needsWeeklyCelebration(), isTrue);
    }
  });

  test(
    'оставленное достижение доступно позднее, показанное не повторяется',
    () {
      final today = DateTime(2026, 10, 11);
      final streak = StudyStreak.fromActivityDays([
        for (var day = 2; day <= 11; day++) DateTime(2026, 10, day),
      ], today: today);
      expect(streak.weeklyAchievementOn, DateTime(2026, 10, 8));
      expect(streak.needsWeeklyCelebration(), isTrue);
      expect(
        streak.needsWeeklyCelebration(celebratedStart: DateTime(2026, 10, 2)),
        isFalse,
      );
      expect(
        streak.needsWeeklyCelebration(celebratedStart: DateTime(2026, 9, 1)),
        isTrue,
      );
    },
  );
}
