import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mosque_session.dart';

class MosqueModePlatform {
  MosqueModePlatform._();
  static const _channel = MethodChannel('com.nooralquran/mosque_mode');
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPolicyAccess() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasPolicyAccess') ?? false;
  }

  static Future<void> openPolicyAccessSettings() async {
    if (isSupported) await _channel.invokeMethod<void>('openPolicyAccessSettings');
  }

  static Future<MosqueModeStatus> startSession(int seconds) => _status('startSession', <String, dynamic>{'durationSeconds': seconds});
  static Future<MosqueModeStatus> cancelSession() => _status('cancelSession');
  static Future<MosqueModeStatus> getSessionStatus() => _status('getSessionStatus');

  static Future<MosqueModeStatus> _status(String method, [Map<String, dynamic>? arguments]) async {
    if (!isSupported) return const MosqueModeStatus.unsupported();
    final values = await _channel.invokeMapMethod<String, dynamic>(method, arguments);
    return MosqueModeStatus.fromMap(values ?? const <String, dynamic>{});
  }
}
