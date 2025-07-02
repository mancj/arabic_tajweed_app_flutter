import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class SharedPref<T> {
  final String key;
  final SharedPreferences sharedPreferences;

  SharedPref(this.key, this.sharedPreferences);

  Future<void> set(T value);

  T get();
}

class BoolSharedPref extends SharedPref<bool?> {
  final bool? defaultValue;

  BoolSharedPref(super.key, super.sharedPreferences, {this.defaultValue});

  @override
  bool? get() {
    return sharedPreferences.getBool(key) ?? defaultValue;
  }

  @override
  Future<void> set(bool? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else {
      await sharedPreferences.setBool(key, value);
    }
  }
}

class IntSharedPref extends SharedPref<int?> {
  final int? defaultValue;

  IntSharedPref(super.key, super.sharedPreferences, {this.defaultValue});

  @override
  int? get() {
    return sharedPreferences.getInt(key) ?? defaultValue;
  }

  @override
  Future<void> set(int? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else {
      await sharedPreferences.setInt(key, value);
    }
  }
}

class DateTimeSharedPref extends SharedPref<DateTime?> {
  final int? defaultValue;

  DateTimeSharedPref(super.key, super.sharedPreferences, {this.defaultValue});

  @override
  DateTime? get() {
    if (sharedPreferences.containsKey(key) || defaultValue != null) {
      final date = sharedPreferences.getString(key);
      if (date != null) {
        return DateTime.parse(date);
      }
    }
    return null;
  }

  @override
  Future<void> set(DateTime? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else {
      await sharedPreferences.setString(key, value.toIso8601String());
    }
  }
}

class StringSharedPref extends SharedPref<String?> {
  final String? defaultValue;

  StringSharedPref(super.key, super.sharedPreferences, {this.defaultValue});

  @override
  String? get() {
    return sharedPreferences.getString(key) ?? defaultValue;
  }

  @override
  Future<void> set(String? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else {
      await sharedPreferences.setString(key, value);
    }
  }
}

class StringListSharedPref extends SharedPref<List<String>> {
  final List<String>? defaultValue;

  StringListSharedPref(super.key, super.sharedPreferences, {this.defaultValue});

  @override
  List<String> get() {
    return sharedPreferences.getStringList(key) ?? defaultValue ?? [];
  }

  @override
  Future<void> set(List<String>? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else {
      await sharedPreferences.setStringList(key, value);
    }
  }
}

class JsonSharedPref<T> extends SharedPref<T?> {
  final T? Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic>? Function(T? model) toJson;

  JsonSharedPref(
    super.key,
    super.sharedPreferences, {
    required this.fromJson,
    required this.toJson,
  });

  @override
  T? get() {
    final json = sharedPreferences.getString(key);
    if (json != null) {
      return fromJson(jsonDecode(json));
    }
    return null;
  }

  @override
  Future<void> set(T? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else {
      await sharedPreferences.setString(key, jsonEncode(toJson(value)));
    }
  }
}
