import 'dart:convert';

import 'package:http/http.dart' as http;

import 'prayer_times.dart';

class PrayerTimesClient {
  PrayerTimesClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<PrayerTimes> fetchByCity({required String city, required String country, required int method}) async {
    final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', <String, String>{'city': city, 'country': country, 'method': '$method'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw PrayerTimesException('تعذر تحديث مواقيت الصلاة الآن.');
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    if (root['code'] != 200 || root['data'] is! Map<String, dynamic>) throw PrayerTimesException('وصلت استجابة غير صالحة لمواقيت الصلاة.');
    final data = root['data'] as Map<String, dynamic>;
    return PrayerTimes.fromAlAdhan(city: city, country: country, method: method, date: DateTime.now(), timings: Map<String, dynamic>.from(data['timings'] as Map));
  }
}

class PrayerTimesException implements Exception {
  PrayerTimesException(this.message);
  final String message;
  @override
  String toString() => message;
}
