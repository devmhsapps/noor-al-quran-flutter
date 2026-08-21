import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mosque_mode_platform.dart';
import 'prayer_store.dart';
import 'prayer_times.dart';
import 'prayer_times_client.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const NoorAlQuranApp()); }

class NoorAlQuranApp extends StatelessWidget {
  const NoorAlQuranApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'نور القرآن', theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123E31)), scaffoldBackgroundColor: const Color(0xFFF7F4EC), fontFamily: 'sans'), home: const Directionality(textDirection: TextDirection.rtl, child: PrayerHomePage()));
}

class PrayerHomePage extends StatefulWidget { const PrayerHomePage({super.key}); @override State<PrayerHomePage> createState() => _PrayerHomePageState(); }

class _PrayerHomePageState extends State<PrayerHomePage> with WidgetsBindingObserver {
  static const _green = Color(0xFF123E31), _gold = Color(0xFFBD892F), _ink = Color(0xFF14231D), _surface = Color(0xFFFFFEF9);
  final _store = PrayerStore();
  final _client = PrayerTimesClient();
  Timer? _ticker;
  PrayerSettings? _settings;
  PrayerTimes? _times;
  MosqueModeStatus _mode = const MosqueModeStatus.unsupported();
  Prayer _schedulePrayer = Prayer.dhuhr;
  int _durationMinutes = 20;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); _load(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _ticker?.cancel(); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _refreshMode(); }

  Future<void> _load({bool forceNetwork = false}) async {
    setState(() { _loading = true; _error = null; });
    final settings = await _store.loadSettings();
    final cached = await _store.loadToday();
    if (!forceNetwork && cached != null) setState(() { _settings = settings; _times = cached; _loading = false; });
    try {
      final times = await _client.fetchByCity(city: settings.city, country: settings.country, method: settings.method);
      await _store.saveTimes(times);
      if (mounted) setState(() { _settings = settings; _times = times; _loading = false; });
    } on PrayerTimesException catch (error) {
      if (mounted) setState(() { _settings = settings; _times ??= cached; _loading = false; _error = _times == null ? error.message : 'نعرض آخر مواقيت محفوظة. تعذر التحديث الآن.'; });
    } finally { await _refreshMode(); }
  }

  Future<void> _refreshMode() async { try { final status = await MosqueModePlatform.getSessionStatus(); if (mounted) setState(() => _mode = status); } on PlatformException { /* The UI remains explicit about unavailable Android functions. */ } }

  Future<void> _schedule() async {
    final times = _times;
    if (times == null) return;
    if (!MosqueModePlatform.isSupported) { _show('تحتاج هذه الوظيفة إلى تثبيت APK على هاتف Android.'); return; }
    if (!_mode.hasPolicyAccess) { await MosqueModePlatform.openPolicyAccessSettings(); _show('امنح التطبيق صلاحية التحكم في عدم الإزعاج ثم عد لإكمال الجدولة.'); return; }
    if (!_mode.hasExactAlarmPermission) { await MosqueModePlatform.openExactAlarmSettings(); _show('فعّل التنبيه الدقيق للتطبيق ثم عد لإكمال الجدولة.'); return; }
    var target = times.dateTimeFor(_schedulePrayer, DateTime.now());
    if (!target.isAfter(DateTime.now().add(const Duration(seconds: 5)))) target = target.add(const Duration(days: 1));
    try {
      final status = await MosqueModePlatform.scheduleSession(at: target, durationSeconds: _durationMinutes * 60);
      if (mounted) setState(() => _mode = status);
      _show('تمت جدولة وضع الجامع عند ${_schedulePrayer.arabicLabel} لمدة $_durationMinutes دقيقة.');
    } on PlatformException catch (error) { _show(error.message ?? 'تعذرت جدولة وضع الجامع.'); }
  }

  Future<void> _startNow() async {
    if (!_mode.hasPolicyAccess) { await MosqueModePlatform.openPolicyAccessSettings(); _show('امنح الصلاحية أولًا من إعدادات Android.'); return; }
    try { final status = await MosqueModePlatform.startSession(_durationMinutes * 60); if (mounted) setState(() => _mode = status); } on PlatformException catch (error) { _show(error.message ?? 'تعذر بدء وضع الجامع.'); }
  }

  void _show(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Future<void> _openSettings() async {
    final current = _settings ?? const PrayerSettings(city: 'Baghdad', country: 'Iraq', method: 4);
    final cityController = TextEditingController(text: current.city), countryController = TextEditingController(text: current.country);
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: _surface, builder: (sheetContext) => Padding(padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.viewInsetsOf(sheetContext).bottom + 26), child: Directionality(textDirection: TextDirection.rtl, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('المدينة وطريقة الحساب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _green)), const SizedBox(height: 8), const Text('عدّل المدينة إذا كانت مواقيت مسجدك تعتمد موقعًا مختلفًا.'), const SizedBox(height: 18), TextField(controller: cityController, decoration: const InputDecoration(labelText: 'المدينة', border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: countryController, decoration: const InputDecoration(labelText: 'الدولة', border: OutlineInputBorder())), const SizedBox(height: 18), FilledButton(onPressed: () async { final city = cityController.text.trim(), country = countryController.text.trim(); if (city.isEmpty || country.isEmpty) return; await _store.saveSettings(PrayerSettings(city: city, country: country, method: 4)); if (sheetContext.mounted) Navigator.pop(sheetContext); await _load(forceNetwork: true); }, style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text('حفظ وتحديث المواقيت'))]))));
    cityController.dispose(); countryController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _times?.nextOccurrence(DateTime.now());
    final scheduled = _mode.scheduledAtMillis > DateTime.now().millisecondsSinceEpoch ? DateTime.fromMillisecondsSinceEpoch(_mode.scheduledAtMillis) : null;
    return Scaffold(
      body: SafeArea(child: RefreshIndicator(onRefresh: () => _load(forceNetwork: true), child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
        Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('نور القرآن', style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 3), Text('مواقيت الأذان ووضع الجامع', style: TextStyle(color: _ink, fontSize: 23, fontWeight: FontWeight.w800))])), IconButton(onPressed: _openSettings, tooltip: 'إعدادات المدينة', icon: const Icon(Icons.tune_rounded, color: _green))]),
        const SizedBox(height: 6), Text(_settings == null ? 'جارٍ تحديد المدينة...' : '${_settings!.city}، ${_settings!.country}', style: const TextStyle(color: Color(0xFF5B675F))), const SizedBox(height: 18),
        if (_loading && _times == null) const _LoadingCard() else if (next != null) _NextPrayerCard(next: next),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: _Notice(text: _error!, color: const Color(0xFF9B6540))),
        const SizedBox(height: 24), const Text('مواقيت اليوم', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
        if (_times != null) _TimingsCard(times: _times!, nextPrayer: next?.prayer),
        const SizedBox(height: 24), const Text('وضع الجامع', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
        _MosqueCard(mode: _mode, selectedPrayer: _schedulePrayer, durationMinutes: _durationMinutes, scheduledAt: scheduled, onPrayerChanged: (value) => setState(() => _schedulePrayer = value), onDurationChanged: (value) => setState(() => _durationMinutes = value), onSchedule: _schedule, onStartNow: _startNow, onCancel: () async { final status = await MosqueModePlatform.cancelScheduledSession(); if (mounted) setState(() => _mode = status); }),
        const SizedBox(height: 18), const _Notice(text: 'تُحفظ المواقيت اليومية على الهاتف بعد نجاح التحديث. لا يتم تفعيل الصامت إلا بعد منح صلاحية Android المطلوبة.', color: Color(0xFF61746A)),
      ]))),
    );
  }
}

class _NextPrayerCard extends StatelessWidget { const _NextPrayerCard({required this.next}); final PrayerOccurrence next; @override Widget build(BuildContext context) { final left = next.time.difference(DateTime.now()).isNegative ? Duration.zero : next.time.difference(DateTime.now()); final text = '${left.inHours.toString().padLeft(2, '0')}:${(left.inMinutes % 60).toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}'; return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF123E31), Color(0xFF1F5A46)]), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('الصلاة القادمة', style: TextStyle(color: Color(0xFFDFD4B2), fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(next.prayer.arabicLabel, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)), const SizedBox(height: 18), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 1.2)), Text('${next.time.hour.toString().padLeft(2, '0')}:${next.time.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xFFE5D2A1), fontSize: 18))]) ])); } }
class _TimingsCard extends StatelessWidget { const _TimingsCard({required this.times, required this.nextPrayer}); final PrayerTimes times; final Prayer? nextPrayer; @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: const Color(0xFFFFFEF9), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7E1D2))), child: Column(children: Prayer.values.map((prayer) { final active = prayer == nextPrayer; return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: active ? const Color(0xFFBD892F) : const Color(0xFFD4D1C8), shape: BoxShape.circle)), const SizedBox(width: 11), Expanded(child: Text(prayer.arabicLabel, style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w600, color: const Color(0xFF14231D)))), Text(times.timeFor(prayer), style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w700, color: active ? const Color(0xFF123E31) : const Color(0xFF526058)))])); }).toList())); }
class _MosqueCard extends StatelessWidget { const _MosqueCard({required this.mode, required this.selectedPrayer, required this.durationMinutes, required this.scheduledAt, required this.onPrayerChanged, required this.onDurationChanged, required this.onSchedule, required this.onStartNow, required this.onCancel}); final MosqueModeStatus mode; final Prayer selectedPrayer; final int durationMinutes; final DateTime? scheduledAt; final ValueChanged<Prayer> onPrayerChanged; final ValueChanged<int> onDurationChanged; final VoidCallback onSchedule; final VoidCallback onStartNow; final VoidCallback onCancel; @override Widget build(BuildContext context) { final ready = mode.hasPolicyAccess && mode.hasExactAlarmPermission; final status = mode.active ? 'مفعّل الآن' : scheduledAt != null ? 'مجدول' : ready ? 'جاهز للجدولة' : 'يلزم إعداد الصلاحيات'; return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFFFFEF9), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7E1D2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.notifications_paused_outlined, color: Color(0xFF123E31)), const SizedBox(width: 9), Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF123E31)))), if (scheduledAt != null) Text('${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w800))]), const SizedBox(height: 16), DropdownButtonFormField<Prayer>(value: selectedPrayer, decoration: const InputDecoration(labelText: 'فعّل وضع الجامع عند', border: OutlineInputBorder()), items: Prayer.values.where((prayer) => prayer.canScheduleMosqueMode).map((prayer) => DropdownMenuItem(value: prayer, child: Text(prayer.arabicLabel))).toList(), onChanged: mode.active ? null : (value) { if (value != null) onPrayerChanged(value); }), const SizedBox(height: 12), Wrap(spacing: 8, children: [10, 20, 30, 45].map((minutes) => ChoiceChip(label: Text('$minutes دقيقة'), selected: durationMinutes == minutes, onSelected: mode.active ? null : (_) => onDurationChanged(minutes))).toList()), const SizedBox(height: 16), if (scheduledAt == null && !mode.active) SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onSchedule, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF123E31), padding: const EdgeInsets.symmetric(vertical: 14)), icon: const Icon(Icons.schedule), label: const Text('جدولة وضع الجامع تلقائيًا'))) else if (mode.active) SizedBox(width: double.infinity, child: FilledButton(onPressed: onCancel, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF933D37)), child: const Text('إلغاء وضع الجامع'))) else SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onCancel, child: const Text('إلغاء الجدولة'))), const SizedBox(height: 8), TextButton(onPressed: mode.active ? null : onStartNow, child: const Text('تجربة وضع الجامع الآن'))])); } }
class _Notice extends StatelessWidget { const _Notice({required this.text, required this.color}); final String text; final Color color; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)), child: Text(text, style: TextStyle(color: color, height: 1.5))); }
class _LoadingCard extends StatelessWidget { const _LoadingCard(); @override Widget build(BuildContext context) => const SizedBox(height: 190, child: Center(child: CircularProgressIndicator())); }
