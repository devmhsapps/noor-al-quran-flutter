import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mosque_mode_platform.dart';
import 'prayer_store.dart';
import 'prayer_times.dart';
import 'prayer_times_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoorAlQuranApp());
}

class NoorAlQuranApp extends StatelessWidget {
  const NoorAlQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور القرآن',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _AppColors.green),
        scaffoldBackgroundColor: _AppColors.background,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: PrayerHomePage(),
      ),
    );
  }
}

class PrayerHomePage extends StatefulWidget {
  const PrayerHomePage({super.key});

  @override
  State<PrayerHomePage> createState() => _PrayerHomePageState();
}

class _PrayerHomePageState extends State<PrayerHomePage>
    with WidgetsBindingObserver {
  final PrayerStore _store = PrayerStore();
  final PrayerTimesClient _client = PrayerTimesClient();
  Timer? _ticker;

  PrayerSettings? _settings;
  PrayerTimes? _times;
  MosqueModeStatus _mode = const MosqueModeStatus.unsupported();
  Prayer _selectedPrayer = Prayer.dhuhr;
  int _durationMinutes = 20;
  bool _loading = true;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshMode();
  }

  Future<void> _load({bool forceNetwork = false}) async {
    setState(() {
      _loading = true;
      _notice = null;
    });

    final settings = await _store.loadSettings();
    final cached = await _store.loadToday();
    if (!forceNetwork && cached != null && mounted) {
      setState(() {
        _settings = settings;
        _times = cached;
        _loading = false;
      });
    }

    try {
      final updated = await _client.fetchByCity(
        city: settings.city,
        country: settings.country,
        method: settings.method,
      );
      await _store.saveTimes(updated);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _times = updated;
        _loading = false;
      });
    } on PrayerTimesException catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _times ??= cached;
        _loading = false;
        _notice = _times == null
            ? error.message
            : 'نعرض آخر مواقيت محفوظة؛ تعذر التحديث الآن.';
      });
    } finally {
      await _refreshMode();
    }
  }

  Future<void> _refreshMode() async {
    try {
      final status = await MosqueModePlatform.getSessionStatus();
      if (mounted) setState(() => _mode = status);
    } on PlatformException {
      if (mounted) setState(() => _notice ??= 'تعذر التحقق من حالة Android.');
    }
  }

  Future<void> _scheduleMosqueMode() async {
    final times = _times;
    if (times == null) return;
    if (!MosqueModePlatform.isSupported) {
      _show('هذه الوظيفة تتطلب تثبيت APK على هاتف Android.');
      return;
    }
    if (!_mode.hasPolicyAccess) {
      await MosqueModePlatform.openPolicyAccessSettings();
      _show('امنح التطبيق صلاحية التحكم في عدم الإزعاج ثم عد لإكمال الجدولة.');
      return;
    }
    if (!_mode.hasExactAlarmPermission) {
      await MosqueModePlatform.openExactAlarmSettings();
      _show('فعّل التنبيهات الدقيقة للتطبيق ثم عد لإكمال الجدولة.');
      return;
    }

    var at = times.dateTimeFor(_selectedPrayer, DateTime.now());
    if (!at.isAfter(DateTime.now().add(const Duration(seconds: 5)))) {
      at = at.add(const Duration(days: 1));
    }

    try {
      final status = await MosqueModePlatform.scheduleSession(
        at: at,
        durationSeconds: _durationMinutes * 60,
      );
      if (!mounted) return;
      setState(() => _mode = status);
      _show('جُدول وضع الجامع عند ${_selectedPrayer.arabicLabel} لمدة $_durationMinutes دقيقة.');
    } on PlatformException catch (error) {
      _show(error.message ?? 'تعذرت جدولة وضع الجامع.');
    }
  }

  Future<void> _startNow() async {
    if (!MosqueModePlatform.isSupported) {
      _show('تتطلب التجربة تثبيت APK على هاتف Android.');
      return;
    }
    if (!_mode.hasPolicyAccess) {
      await MosqueModePlatform.openPolicyAccessSettings();
      _show('امنح الصلاحية أولًا من إعدادات Android.');
      return;
    }
    try {
      final status =
          await MosqueModePlatform.startSession(_durationMinutes * 60);
      if (mounted) setState(() => _mode = status);
    } on PlatformException catch (error) {
      _show(error.message ?? 'تعذر بدء وضع الجامع.');
    }
  }

  Future<void> _cancelMode() async {
    try {
      final status = _mode.active
          ? await MosqueModePlatform.cancelSession()
          : await MosqueModePlatform.cancelScheduledSession();
      if (mounted) setState(() => _mode = status);
    } on PlatformException catch (error) {
      _show(error.message ?? 'تعذر إلغاء وضع الجامع.');
    }
  }

  Future<void> _editCity() async {
    final initial = _settings ??
        const PrayerSettings(city: 'Baghdad', country: 'Iraq', method: 4);
    final city = TextEditingController(text: initial.city);
    final country = TextEditingController(text: initial.country);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _AppColors.surface,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              22,
              22,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 26,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('المدينة وطريقة الحساب',
                    style: TextStyle(
                        color: _AppColors.green,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('اختر مدينة مسجدك لضبط مواقيت اليوم.'),
                const SizedBox(height: 18),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(
                    labelText: 'المدينة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: country,
                  decoration: const InputDecoration(
                    labelText: 'الدولة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () async {
                    final nextCity = city.text.trim();
                    final nextCountry = country.text.trim();
                    if (nextCity.isEmpty || nextCountry.isEmpty) return;
                    await _store.saveSettings(PrayerSettings(
                      city: nextCity,
                      country: nextCountry,
                      method: 4,
                    ));
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    await _load(forceNetwork: true);
                  },
                  child: const Text('حفظ وتحديث المواقيت'),
                ),
              ],
            ),
          ),
        );
      },
    );
    city.dispose();
    country.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final times = _times;
    final next = times?.nextOccurrence(DateTime.now());
    final scheduledAt = _mode.scheduledAtMillis > DateTime.now().millisecondsSinceEpoch
        ? DateTime.fromMillisecondsSinceEpoch(_mode.scheduledAtMillis)
        : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(forceNetwork: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              _Header(
                cityLabel: _settings == null
                    ? 'جارٍ تحديد المدينة...'
                    : '${_settings!.city}، ${_settings!.country}',
                onSettings: _editCity,
              ),
              const SizedBox(height: 20),
              if (_loading && times == null)
                const _LoadingPanel()
              else if (next != null)
                _NextPrayerPanel(next: next),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                _InfoPanel(text: _notice!, color: const Color(0xFF9A6340)),
              ],
              const SizedBox(height: 25),
              const _SectionTitle('مواقيت اليوم'),
              const SizedBox(height: 10),
              if (times != null) _PrayerList(times: times, nextPrayer: next?.prayer),
              const SizedBox(height: 25),
              const _SectionTitle('وضع الجامع'),
              const SizedBox(height: 10),
              _MosqueModePanel(
                status: _mode,
                selectedPrayer: _selectedPrayer,
                durationMinutes: _durationMinutes,
                scheduledAt: scheduledAt,
                onPrayerChanged: (value) => setState(() => _selectedPrayer = value),
                onDurationChanged: (value) =>
                    setState(() => _durationMinutes = value),
                onSchedule: _scheduleMosqueMode,
                onStartNow: _startNow,
                onCancel: _cancelMode,
              ),
              const SizedBox(height: 16),
              const _InfoPanel(
                text:
                    'بعد تحديث المواقيت تُحفظ على الهاتف لليوم الحالي. يعيد وضع الجامع إعداد عدم الإزعاج السابق تلقائيًا عند انتهاء الجلسة.',
                color: Color(0xFF607368),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cityLabel, required this.onSettings});
  final String cityLabel;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نور القرآن',
                  style: TextStyle(
                      color: _AppColors.gold,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8)),
              const SizedBox(height: 3),
              const Text('مواقيت الأذان ووضع الجامع',
                  style: TextStyle(
                      color: _AppColors.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(cityLabel,
                  style: const TextStyle(color: _AppColors.muted)),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          tooltip: 'إعدادات المدينة',
          icon: const Icon(Icons.tune_rounded, color: _AppColors.green),
        ),
      ],
    );
  }
}

class _NextPrayerPanel extends StatelessWidget {
  const _NextPrayerPanel({required this.next});
  final PrayerOccurrence next;

  @override
  Widget build(BuildContext context) {
    final difference = next.time.difference(DateTime.now());
    final safe = difference.isNegative ? Duration.zero : difference;
    final countdown =
        '${safe.inHours.toString().padLeft(2, '0')}:${(safe.inMinutes % 60).toString().padLeft(2, '0')}:${(safe.inSeconds % 60).toString().padLeft(2, '0')}';
    final clock =
        '${next.time.hour.toString().padLeft(2, '0')}:${next.time.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123E31), Color(0xFF21614B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الصلاة القادمة',
              style: TextStyle(color: Color(0xFFE7DAB5), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(next.prayer.arabicLabel,
              style: const TextStyle(
                  color: Colors.white, fontSize: 35, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(countdown,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
              Text(clock,
                  style: const TextStyle(
                      color: Color(0xFFE7DAB5),
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerList extends StatelessWidget {
  const _PrayerList({required this.times, required this.nextPrayer});
  final PrayerTimes times;
  final Prayer? nextPrayer;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: Prayer.values.map((prayer) {
          final isNext = prayer == nextPrayer;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isNext ? _AppColors.gold : const Color(0xFFD4D2C9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(prayer.arabicLabel,
                      style: TextStyle(
                          color: _AppColors.ink,
                          fontWeight:
                              isNext ? FontWeight.w900 : FontWeight.w600)),
                ),
                Text(times.timeFor(prayer),
                    style: TextStyle(
                        color: isNext ? _AppColors.green : _AppColors.muted,
                        fontWeight:
                            isNext ? FontWeight.w900 : FontWeight.w800)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MosqueModePanel extends StatelessWidget {
  const _MosqueModePanel({
    required this.status,
    required this.selectedPrayer,
    required this.durationMinutes,
    required this.scheduledAt,
    required this.onPrayerChanged,
    required this.onDurationChanged,
    required this.onSchedule,
    required this.onStartNow,
    required this.onCancel,
  });

  final MosqueModeStatus status;
  final Prayer selectedPrayer;
  final int durationMinutes;
  final DateTime? scheduledAt;
  final ValueChanged<Prayer> onPrayerChanged;
  final ValueChanged<int> onDurationChanged;
  final VoidCallback onSchedule;
  final VoidCallback onStartNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isReady = status.hasPolicyAccess && status.hasExactAlarmPermission;
    final label = status.active
        ? 'مفعّل الآن'
        : scheduledAt != null
            ? 'مجدول'
            : isReady
                ? 'جاهز للجدولة'
                : 'يحتاج إعداد الصلاحيات';
    final scheduledLabel = scheduledAt == null
        ? null
        : '${scheduledAt!.hour.toString().padLeft(2, '0')}:${scheduledAt!.minute.toString().padLeft(2, '0')}';

    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_paused_outlined,
                    color: _AppColors.green),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: _AppColors.green,
                          fontWeight: FontWeight.w900)),
                ),
                if (scheduledLabel != null)
                  Text(scheduledLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Prayer>(
              value: selectedPrayer,
              decoration: const InputDecoration(
                labelText: 'فعّل وضع الجامع عند',
                border: OutlineInputBorder(),
              ),
              items: Prayer.values
                  .where((item) => item.canScheduleMosqueMode)
                  .map((item) => DropdownMenuItem(
                      value: item, child: Text(item.arabicLabel)))
                  .toList(),
              onChanged: status.active
                  ? null
                  : (value) {
                      if (value != null) onPrayerChanged(value);
                    },
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10, 20, 30, 45]
                  .map((minutes) => ChoiceChip(
                        label: Text('$minutes دقيقة'),
                        selected: durationMinutes == minutes,
                        onSelected: status.active
                            ? null
                            : (_) => onDurationChanged(minutes),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 17),
            if (status.active)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onCancel,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF933D37)),
                  child: const Text('إلغاء وضع الجامع'),
                ),
              )
            else if (scheduledAt != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('إلغاء الجدولة'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSchedule,
                  style: FilledButton.styleFrom(
                    backgroundColor: _AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.schedule),
                  label: const Text('جدولة وضع الجامع تلقائيًا'),
                ),
              ),
            const SizedBox(height: 5),
            TextButton(
              onPressed: status.active ? null : onStartNow,
              child: const Text('تجربة وضع الجامع الآن'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E0D2)),
      ),
      child: child,
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: color, height: 1.5)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: _AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900));
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 190,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

abstract final class _AppColors {
  static const green = Color(0xFF123E31);
  static const gold = Color(0xFFBD892F);
  static const ink = Color(0xFF14231D);
  static const muted = Color(0xFF5C6A61);
  static const background = Color(0xFFF7F4EC);
  static const surface = Color(0xFFFFFEF9);
}
