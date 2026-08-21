import 'package:flutter_test/flutter_test.dart';
import 'package:noor_al_quran/prayer_times.dart';

void main() {
  final times = PrayerTimes.fromAlAdhan(city: 'Baghdad', country: 'Iraq', method: 4, date: DateTime(2026, 8, 21), timings: <String, dynamic>{'Fajr': '04:15', 'Sunrise': '05:43', 'Dhuhr': '12:06', 'Asr': '15:39', 'Maghrib': '18:29', 'Isha': '19:51'});
  test('ينظف وقت المصدر ويكوّن وقتًا محليًا', () { expect(times.timeFor(Prayer.dhuhr), '12:06'); expect(times.dateTimeFor(Prayer.dhuhr).hour, 12); });
  test('يختار الصلاة التالية في اليوم نفسه', () { final result = times.nextOccurrence(DateTime(2026, 8, 21, 12, 7)); expect(result.prayer, Prayer.asr); });
  test('ينتقل إلى فجر اليوم التالي بعد العشاء', () { final result = times.nextOccurrence(DateTime(2026, 8, 21, 20)); expect(result.prayer, Prayer.fajr); expect(result.time.day, 22); });
}
