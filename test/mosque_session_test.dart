import 'package:flutter_test/flutter_test.dart';
import 'package:noor_al_quran/mosque_session.dart';

void main() {
  group('منطق وقت وضع الجامع', () {
    test('ينسق الدقائق والثواني بصيغة ثابتة', () { expect(formatRemaining(0), '00:00'); expect(formatRemaining(125), '02:05'); });
    test('ينهي الجلسة عند الصفر', () { const status = MosqueModeStatus(isSupported: true, hasPolicyAccess: true, active: true, endsAtMillis: 10000, remainingSeconds: 0); expect(remainingSecondsAt(10000, 10000), 0); expect(isSessionActive(status, 10000), isFalse); });
    test('يبقي الجلسة مفعلة قبل لحظة النهاية', () { const status = MosqueModeStatus(isSupported: true, hasPolicyAccess: true, active: true, endsAtMillis: 10000, remainingSeconds: 1); expect(remainingSecondsAt(10000, 9001), 1); expect(isSessionActive(status, 9999), isTrue); });
  });
}
