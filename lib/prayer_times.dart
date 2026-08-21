import 'dart:collection';

enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerLabel on Prayer {
  String get arabicLabel => switch (this) {
        Prayer.fajr => 'الفجر',
        Prayer.sunrise => 'الشروق',
        Prayer.dhuhr => 'الظهر',
        Prayer.asr => 'العصر',
        Prayer.maghrib => 'المغرب',
        Prayer.isha => 'العشاء',
      };

  bool get canScheduleMosqueMode => this != Prayer.sunrise;
}

class PrayerOccurrence {
  const PrayerOccurrence(this.prayer, this.time);
  final Prayer prayer;
  final DateTime time;
}

class PrayerTimes {
  const PrayerTimes({
    required this.city,
    required this.country,
    required this.method,
    required this.date,
    required this.timings,
  });

  final String city;
  final String country;
  final int method;
  final DateTime date;
  final Map<Prayer, String> timings;

  String timeFor(Prayer prayer) => timings[prayer] ?? '--:--';

  DateTime dateTimeFor(Prayer prayer, [DateTime? targetDay]) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeFor(prayer));
    if (match == null) throw FormatException('وقت الصلاة غير صالح: ${timeFor(prayer)}');
    final day = targetDay ?? date;
    return DateTime(day.year, day.month, day.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  PrayerOccurrence nextOccurrence(DateTime now) {
    for (final prayer in Prayer.values) {
      final occurrence = dateTimeFor(prayer, now);
      if (occurrence.isAfter(now)) return PrayerOccurrence(prayer, occurrence);
    }
    return PrayerOccurrence(Prayer.fajr, dateTimeFor(Prayer.fajr, now.add(const Duration(days: 1))));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'city': city,
        'country': country,
        'method': method,
        'date': date.toIso8601String(),
        'timings': <String, String>{for (final item in timings.entries) item.key.name: item.value},
      };

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final sourceTimings = Map<String, dynamic>.from(json['timings'] as Map);
    return PrayerTimes(
      city: json['city'] as String,
      country: json['country'] as String,
      method: (json['method'] as num).toInt(),
      date: DateTime.parse(json['date'] as String),
      timings: UnmodifiableMapView<Prayer, String>({
        for (final prayer in Prayer.values) prayer: _cleanTime(sourceTimings[prayer.name]?.toString() ?? '--:--'),
      }),
    );
  }

  factory PrayerTimes.fromAlAdhan({
    required String city,
    required String country,
    required int method,
    required DateTime date,
    required Map<String, dynamic> timings,
  }) => PrayerTimes(
        city: city,
        country: country,
        method: method,
        date: DateTime(date.year, date.month, date.day),
        timings: UnmodifiableMapView<Prayer, String>({
          Prayer.fajr: _cleanTime(timings['Fajr']?.toString() ?? '--:--'),
          Prayer.sunrise: _cleanTime(timings['Sunrise']?.toString() ?? '--:--'),
          Prayer.dhuhr: _cleanTime(timings['Dhuhr']?.toString() ?? '--:--'),
          Prayer.asr: _cleanTime(timings['Asr']?.toString() ?? '--:--'),
          Prayer.maghrib: _cleanTime(timings['Maghrib']?.toString() ?? '--:--'),
          Prayer.isha: _cleanTime(timings['Isha']?.toString() ?? '--:--'),
        }),
      );
}

String _cleanTime(String source) => RegExp(r'\d{1,2}:\d{2}').firstMatch(source)?.group(0)?.padLeft(5, '0') ?? '--:--';
