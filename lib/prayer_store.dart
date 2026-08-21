import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_times.dart';

class PrayerSettings {
  const PrayerSettings({required this.city, required this.country, required this.method});
  final String city;
  final String country;
  final int method;
}

class PrayerStore {
  static const _timesKey = 'prayer_times';
  static const _cityKey = 'prayer_city';
  static const _countryKey = 'prayer_country';
  static const _methodKey = 'prayer_method';

  Future<PrayerSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return PrayerSettings(city: prefs.getString(_cityKey) ?? 'Baghdad', country: prefs.getString(_countryKey) ?? 'Iraq', method: prefs.getInt(_methodKey) ?? 4);
  }

  Future<void> saveSettings(PrayerSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, settings.city.trim());
    await prefs.setString(_countryKey, settings.country.trim());
    await prefs.setInt(_methodKey, settings.method);
  }

  Future<void> saveTimes(PrayerTimes times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timesKey, jsonEncode(times.toJson()));
  }

  Future<PrayerTimes?> loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timesKey);
    if (raw == null) return null;
    try {
      final times = PrayerTimes.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      final now = DateTime.now();
      return times.date.year == now.year && times.date.month == now.month && times.date.day == now.day ? times : null;
    } catch (_) {
      return null;
    }
  }
}
