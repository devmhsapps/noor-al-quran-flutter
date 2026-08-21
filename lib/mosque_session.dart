class MosqueModeStatus {
  const MosqueModeStatus({
    required this.isSupported,
    required this.hasPolicyAccess,
    required this.active,
    required this.endsAtMillis,
    required this.remainingSeconds,
  });

  const MosqueModeStatus.unsupported()
      : isSupported = false,
        hasPolicyAccess = false,
        active = false,
        endsAtMillis = 0,
        remainingSeconds = 0;

  final bool isSupported;
  final bool hasPolicyAccess;
  final bool active;
  final int endsAtMillis;
  final int remainingSeconds;

  factory MosqueModeStatus.fromMap(Map<String, dynamic> values) {
    int asInt(dynamic value) => value is int ? value : (value as num?)?.toInt() ?? 0;
    return MosqueModeStatus(
      isSupported: values['isSupported'] == true,
      hasPolicyAccess: values['hasPolicyAccess'] == true,
      active: values['active'] == true,
      endsAtMillis: asInt(values['endsAtMillis']),
      remainingSeconds: asInt(values['remainingSeconds']),
    );
  }
}

String formatRemaining(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final remainder = safeSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

int remainingSecondsAt(int endsAtMillis, int nowMillis) {
  final difference = endsAtMillis - nowMillis;
  if (difference <= 0) return 0;
  return (difference / 1000).ceil();
}

bool isSessionActive(MosqueModeStatus status, int nowMillis) => status.active && status.endsAtMillis > nowMillis;
