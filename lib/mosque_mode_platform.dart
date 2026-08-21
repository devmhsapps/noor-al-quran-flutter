import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mosque_session.dart';

class MosqueModeStatus {
  const MosqueModeStatus({required this.isSupported, required this.hasPolicyAccess, required this.hasExactAlarmPermission, required this.active, required this.endsAtMillis, required this.scheduledAtMillis, required this.remainingSeconds});
  const MosqueModeStatus.unsupported() : isSupported = false, hasPolicyAccess = false, hasExactAlarmPermission = false, active = false, endsAtMillis = 0, scheduledAtMillis = 0, remainingSeconds = 0;
  final bool isSupported;
  final bool hasPolicyAccess;
  final bool hasExactAlarmPermission;
  final bool active;
  final int endsAtMillis;
  final int scheduledAtMillis;
  final int remainingSeconds;
  factory MosqueModeStatus.fromMap(Map<String, dynamic> values) {
    int number(dynamic value) => value is int ? value : (value as num?)?.toInt() ?? 0;
    return MosqueModeStatus(isSupported: values['isSupported'] == true, hasPolicyAccess: values['hasPolicyAccess'] == true, hasExactAlarmPermission: values['hasExactAlarmPermission'] == true, active: values['active'] == true, endsAtMillis: number(values['endsAtMillis']), scheduledAtMillis: number(values['scheduledAtMillis']), remainingSeconds: number(values['remainingSeconds']));
  }
}

class MosqueModePlatform {
  MosqueModePlatform._();
  static const _channel = MethodChannel('com.nooralquran/mosque_mode');
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.android;
  static Future<MosqueModeStatus> getSessionStatus() => _status('getSessionStatus');
  static Future<void> openPolicyAccessSettings() => _callVoid('openPolicyAccessSettings');
  static Future<void> openExactAlarmSettings() => _callVoid('openExactAlarmSettings');
  static Future<MosqueModeStatus> startSession(int seconds) => _status('startSession', <String, dynamic>{'durationSeconds': seconds});
  static Future<MosqueModeStatus> cancelSession() => _status('cancelSession');
  static Future<MosqueModeStatus> scheduleSession({required DateTime at, required int durationSeconds}) => _status('scheduleSession', <String, dynamic>{'atMillis': at.millisecondsSinceEpoch, 'durationSeconds': durationSeconds});
  static Future<MosqueModeStatus> cancelScheduledSession() => _status('cancelScheduledSession');
  static Future<void> _callVoid(String method) async { if (isSupported) await _channel.invokeMethod<void>(method); }
  static Future<MosqueModeStatus> _status(String method, [Map<String, dynamic>? arguments]) async {
    if (!isSupported) return const MosqueModeStatus.unsupported();
    final values = await _channel.invokeMapMethod<String, dynamic>(method, arguments);
    return MosqueModeStatus.fromMap(values ?? const <String, dynamic>{});
  }
}
