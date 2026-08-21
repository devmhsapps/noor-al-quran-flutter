import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mosque_mode_platform.dart';
import 'mosque_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoorAlQuranApp());
}

class NoorAlQuranApp extends StatelessWidget {
  const NoorAlQuranApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'نور القرآن',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3D2E)), scaffoldBackgroundColor: const Color(0xFFF8F5EE), useMaterial3: true),
        home: const Directionality(textDirection: TextDirection.rtl, child: MosqueModePage()),
      );
}

class MosqueModePage extends StatefulWidget {
  const MosqueModePage({super.key});
  @override
  State<MosqueModePage> createState() => _MosqueModePageState();
}

class _MosqueModePageState extends State<MosqueModePage> with WidgetsBindingObserver {
  static const _green = Color(0xFF0B3D2E);
  static const _gold = Color(0xFFC58A28);
  static const _ivory = Color(0xFFF8F5EE);
  static const _red = Color(0xFF9C3D35);
  static const _durations = <_DurationOption>[
    _DurationOption(seconds: 120, label: 'دقيقتان'),
    _DurationOption(seconds: 300, label: '5 دقائق'),
    _DurationOption(seconds: 900, label: '15 دقيقة'),
    _DurationOption(seconds: 1800, label: '30 دقيقة'),
  ];
  MosqueModeStatus _status = const MosqueModeStatus.unsupported();
  int _selectedSeconds = 120;
  String _message = 'هذه النسخة تحتاج تثبيت APK على هاتف Android حقيقي.';
  bool _working = false;
  Timer? _ticker;
  bool get _active => isSessionActive(_status, DateTime.now().millisecondsSinceEpoch);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (_active) _refresh(); });
    _refresh();
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _ticker?.cancel(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _refresh(); }

  Future<void> _refresh() async {
    if (!MosqueModePlatform.isSupported) {
      if (mounted) setState(() { _status = const MosqueModeStatus.unsupported(); _message = 'هذه المعاينة لا تتضمن كود Android الأصلي. نحتاج تثبيت النسخة التجريبية على الهاتف.'; });
      return;
    }
    try {
      final wasActive = _status.active;
      final next = await MosqueModePlatform.getSessionStatus();
      if (!mounted) return;
      setState(() { _status = next; if (wasActive && !next.active) _message = 'انتهى وضع الجامع وعاد الهاتف إلى إعداد عدم الإزعاج السابق.'; });
    } on PlatformException { if (mounted) setState(() => _message = 'تعذر قراءة حالة Android. تأكد من تثبيت APK الصحيح.'); }
  }

  Future<void> _grantAccess() async {
    if (!MosqueModePlatform.isSupported) { setState(() => _message = 'هذه المعاينة لا تتضمن كود Android الأصلي. نحتاج تثبيت النسخة التجريبية على الهاتف.'); return; }
    setState(() => _working = true);
    try {
      if (await MosqueModePlatform.hasPolicyAccess()) { setState(() => _message = 'الصلاحية متاحة الآن. يمكنك تفعيل وضع الجامع.'); await _refresh(); }
      else { await MosqueModePlatform.openPolicyAccessSettings(); setState(() => _message = 'امنح التطبيق صلاحية التحكم في عدم الإزعاج من إعدادات Android.'); }
    } on PlatformException { setState(() => _message = 'تعذر فتح إعدادات الصلاحية.'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _activate() async {
    setState(() => _working = true);
    try {
      if (!await MosqueModePlatform.hasPolicyAccess()) { setState(() => _message = 'امنح التطبيق صلاحية التحكم في عدم الإزعاج من إعدادات Android.'); return; }
      final next = await MosqueModePlatform.startSession(_selectedSeconds);
      setState(() { _status = next; _message = 'تم تفعيل وضع الجامع. سيُعاد الوضع السابق تلقائياً عند انتهاء الوقت.'; });
    } on PlatformException catch (error) { setState(() => _message = error.message ?? 'لم يكتمل تفعيل وضع الجامع.'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _cancel() async {
    setState(() => _working = true);
    try { final next = await MosqueModePlatform.cancelSession(); setState(() { _status = next; _message = 'أُلغي وضع الجامع وعاد الهاتف إلى وضع عدم الإزعاج السابق.'; }); }
    on PlatformException { setState(() => _message = 'تعذر إلغاء الجلسة. أعد فتح التطبيق وتحقق من Android.'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final selected = _durations.firstWhere((option) => option.seconds == _selectedSeconds);
    final stateLabel = active ? 'مفعّل' : _status.hasPolicyAccess ? 'جاهز' : 'صلاحية مطلوبة';
    final remaining = active ? remainingSecondsAt(_status.endsAtMillis, DateTime.now().millisecondsSinceEpoch) : 0;
    final actionLabel = active ? 'إلغاء وضع الجامع' : _status.hasPolicyAccess ? 'تفعيل وضع الجامع' : 'منح الصلاحية';
    final action = active ? _cancel : _status.hasPolicyAccess ? _activate : _grantAccess;
    return Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(children: [
        const Text('نور القرآن', style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4), const Text('وضع الجامع', style: TextStyle(color: _green, fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2), const Text('اختبار الهدوء المؤقت', style: TextStyle(color: Color(0xFF5D665F), fontSize: 16)), const SizedBox(height: 10),
        _StatusChip(label: stateLabel, active: active || _status.hasPolicyAccess), const SizedBox(height: 22),
        _TimerCard(heading: active ? 'الوقت المتبقي' : 'المدة المختارة', value: active ? formatRemaining(remaining) : selected.label, active: active), const SizedBox(height: 20),
        const Align(alignment: Alignment.centerRight, child: Text('اختر المدة', style: TextStyle(color: _green, fontSize: 15, fontWeight: FontWeight.w800))), const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: _durations.map((option) { final isSelected = option.seconds == _selectedSeconds; return SizedBox(width: (MediaQuery.sizeOf(context).width - 50) / 2, child: OutlinedButton(onPressed: active ? null : () => setState(() => _selectedSeconds = option.seconds), style: OutlinedButton.styleFrom(backgroundColor: isSelected ? _green : const Color(0xFFFFFEFA), foregroundColor: isSelected ? _ivory : _green, side: BorderSide(color: isSelected ? _green : const Color(0xFFDED6C5)), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(option.label, style: const TextStyle(fontWeight: FontWeight.w800)))); }).toList()),
        const SizedBox(height: 18), Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF1EEE6), borderRadius: BorderRadius.circular(12), border: const Border(right: BorderSide(color: _gold, width: 3))), padding: const EdgeInsets.all(13), child: Text(_message, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF4A544D), height: 1.45))),
        const Spacer(), SizedBox(width: double.infinity, height: 58, child: FilledButton(onPressed: _working ? null : action, style: FilledButton.styleFrom(backgroundColor: active ? _red : _green, foregroundColor: _ivory, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(_working ? 'جارٍ التحقق...' : actionLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))), const SizedBox(height: 10),
        const Text('يتطلب الاختبار النهائي تثبيت APK على هاتف Android حقيقي.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5D665F), fontSize: 12)),
      ]),
    )));
  }
}

class _DurationOption { const _DurationOption({required this.seconds, required this.label}); final int seconds; final String label; }
class _StatusChip extends StatelessWidget { const _StatusChip({required this.label, required this.active}); final String label; final bool active; @override Widget build(BuildContext context) { final color = active ? const Color(0xFF2E7D5B) : const Color(0xFF9C3D35); return Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7), decoration: BoxDecoration(color: active ? const Color(0xFFE3ECE5) : const Color(0xFFF8E6E2), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800))])); } }
class _TimerCard extends StatelessWidget { const _TimerCard({required this.heading, required this.value, required this.active}); final String heading; final String value; final bool active; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28), decoration: BoxDecoration(color: const Color(0xFFFFFEFA), border: Border.all(color: const Color(0xFFDED6C5)), borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x140B3D2E), blurRadius: 16, offset: Offset(0, 8))]), child: Column(children: [Text(heading, style: const TextStyle(color: Color(0xFF5D665F), fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(value, style: TextStyle(color: const Color(0xFF0B3D2E), fontSize: active ? 48 : 34, fontWeight: FontWeight.w800)), const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFECE6D9))), Text(active ? 'سيُعاد الإعداد السابق تلقائياً عند النهاية.' : 'اختر مدة الجلسة قبل التفعيل.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5D665F), fontSize: 13))])); }
