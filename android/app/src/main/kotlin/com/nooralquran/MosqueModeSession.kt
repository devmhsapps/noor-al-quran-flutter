package com.nooralquran

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import kotlin.math.ceil

object MosqueModeSession {
    private const val preferencesName = "mosque_mode_session"
    private const val activeKey = "active"
    private const val priorFilterKey = "prior_filter"
    private const val endsAtKey = "ends_at"
    private const val scheduledAtKey = "scheduled_at"
    private const val scheduledDurationKey = "scheduled_duration"
    private const val noSavedFilter = -1

    fun hasPolicyAccess(context: Context): Boolean = notificationManager(context).isNotificationPolicyAccessGranted
    fun hasExactAlarmPermission(context: Context): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager(context).canScheduleExactAlarms()
    fun hasStoredSession(context: Context): Boolean = preferences(context).getBoolean(activeKey, false)

    fun begin(context: Context, durationSeconds: Int) {
        val manager = notificationManager(context)
        check(manager.isNotificationPolicyAccessGranted) { "صلاحية عدم الإزعاج غير متاحة." }
        cancelScheduled(context)
        restore(context)
        val endsAtMillis = System.currentTimeMillis() + durationSeconds * 1000L
        preferences(context).edit().putBoolean(activeKey, true).putInt(priorFilterKey, manager.currentInterruptionFilter).putLong(endsAtKey, endsAtMillis).commit()
        manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        ContextCompat.startForegroundService(context, Intent(context, MosqueModeService::class.java).setAction(MosqueModeService.actionResume))
    }

    fun schedule(context: Context, atMillis: Long, durationSeconds: Int) {
        check(hasPolicyAccess(context)) { "امنح التطبيق صلاحية التحكم في عدم الإزعاج أولًا." }
        check(hasExactAlarmPermission(context)) { "فعّل التنبيه الدقيق للتطبيق من إعدادات Android أولًا." }
        check(atMillis > System.currentTimeMillis()) { "اختر وقتًا قادمًا لوضع الجامع." }
        cancelScheduled(context)
        preferences(context).edit().putLong(scheduledAtKey, atMillis).putInt(scheduledDurationKey, durationSeconds).commit()
        val pending = scheduledPendingIntent(context)
        alarmManager(context).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
    }

    fun startScheduledSession(context: Context) {
        val prefs = preferences(context)
        val duration = prefs.getInt(scheduledDurationKey, 0)
        val scheduledAt = prefs.getLong(scheduledAtKey, 0L)
        if (duration <= 0 || scheduledAt <= 0L) return
        cancelScheduled(context)
        if (hasPolicyAccess(context)) begin(context, duration)
    }

    fun cancel(context: Context) { restore(context); cancelScheduled(context); context.stopService(Intent(context, MosqueModeService::class.java)) }
    fun cancelScheduled(context: Context) { alarmManager(context).cancel(scheduledPendingIntent(context)); preferences(context).edit().remove(scheduledAtKey).remove(scheduledDurationKey).commit() }
    fun restoreIfExpired(context: Context) { if (preferences(context).getBoolean(activeKey, false) && preferences(context).getLong(endsAtKey, 0L) <= System.currentTimeMillis()) restore(context) }
    fun restore(context: Context) { val prefs = preferences(context); val saved = prefs.getInt(priorFilterKey, noSavedFilter); if (saved != noSavedFilter && notificationManager(context).isNotificationPolicyAccessGranted) notificationManager(context).setInterruptionFilter(saved); prefs.edit().remove(activeKey).remove(priorFilterKey).remove(endsAtKey).commit() }

    fun status(context: Context): Map<String, Any> {
        val prefs = preferences(context)
        val ends = prefs.getLong(endsAtKey, 0L)
        val active = prefs.getBoolean(activeKey, false) && ends > System.currentTimeMillis()
        val remaining = if (active) ceil((ends - System.currentTimeMillis()) / 1000.0).toInt().coerceAtLeast(0) else 0
        val scheduled = prefs.getLong(scheduledAtKey, 0L).takeIf { it > System.currentTimeMillis() } ?: 0L
        return mapOf("isSupported" to true, "hasPolicyAccess" to hasPolicyAccess(context), "hasExactAlarmPermission" to hasExactAlarmPermission(context), "active" to active, "endsAtMillis" to if (active) ends else 0L, "scheduledAtMillis" to scheduled, "remainingSeconds" to remaining)
    }

    private fun scheduledPendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(context, 7331, Intent(context, MosqueModeAlarmReceiver::class.java).setAction(MosqueModeAlarmReceiver.actionStart), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun preferences(context: Context) = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
    private fun notificationManager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun alarmManager(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
}
