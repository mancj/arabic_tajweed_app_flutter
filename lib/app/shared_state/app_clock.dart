import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/utils/shared_pref.dart';

/// Единое время приложения. В debug выбранный календарный день подменяет
/// сегодняшний, сохраняя текущее время суток и его обычный ход.
class AppClock extends GetxService {
  AppClock({DateTime Function()? systemNow, SharedPreferences? preferences})
    : _systemNow = systemNow ?? DateTime.now,
      _debugTodayPreference = preferences == null
          ? null
          : DateTimeSharedPref('debugToday', preferences) {
    if (kDebugMode) _debugToday.value = _debugTodayPreference?.get();
  }

  final DateTime Function() _systemNow;
  final DateTimeSharedPref? _debugTodayPreference;
  final _debugToday = Rxn<DateTime>();

  DateTime get now {
    final actual = _systemNow();
    final debugToday = _debugToday.value;
    if (debugToday == null) return actual;
    return DateTime(
      debugToday.year,
      debugToday.month,
      debugToday.day,
      actual.hour,
      actual.minute,
      actual.second,
      actual.millisecond,
      actual.microsecond,
    );
  }

  Future<void> setDebugToday(DateTime date) async {
    if (!kDebugMode) return;
    final today = DateTime(date.year, date.month, date.day);
    _debugToday.value = today;
    await _debugTodayPreference?.set(today);
  }
}
