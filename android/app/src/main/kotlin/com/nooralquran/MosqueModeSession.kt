package com.nooralquran

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import kotlin.math.ceil

object MosqueModeSession {
    private const val preferencesName = "mosque_mode_session"
    private const val activeKey = "active"
    private const val priorFilterKey = "prior_filter"
    private const val endsAtKey = "ends_at"
    private const val noSavedFilter = -1
    fun hasPolicyAccess(context: Context): Boolean = manager(context).isNotificationPolicyAccessGranted
    fun hasStoredSession(context: Context): Boolean = preferences(context).getBoolean(activeKey, false)
    fun begin(context: Context, durationSeconds: Int) {
        val notificationManager = manager(context)
        check(notificationManager.isNotificationPolicyAccessGranted) { "صلاحية عدم الإزعاج غير متاحة." }
        restore(context)
        val endsAtMillis = System.currentTimeMillis() + durationSeconds * 1000L
        preferences(context).edit().putBoolean(activeKey, true).putInt(priorFilterKey, notificationManager.currentInterruptionFilter).putLong(endsAtKey, endsAtMillis).commit()
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        ContextCompat.startForegroundService(context, Intent(context, MosqueModeService::class.java).setAction(MosqueModeService.actionResume))
    }
    fun cancel(context: Context) { restore(context); context.stopService(Intent(context, MosqueModeService::class.java)) }
    fun restoreIfExpired(context: Context) { if (preferences(context).getBoolean(activeKey, false) && preferences(context).getLong(endsAtKey, 0L) <= System.currentTimeMillis()) restore(context) }
    fun restore(context: Context) { val prefs = preferences(context); val saved = prefs.getInt(priorFilterKey, noSavedFilter); if (saved != noSavedFilter && manager(context).isNotificationPolicyAccessGranted) manager(context).setInterruptionFilter(saved); prefs.edit().clear().commit() }
    fun status(context: Context): Map<String, Any> { val prefs = preferences(context); val ends = prefs.getLong(endsAtKey, 0L); val active = prefs.getBoolean(activeKey, false) && ends > System.currentTimeMillis(); val remaining = if (active) ceil((ends - System.currentTimeMillis()) / 1000.0).toInt().coerceAtLeast(0) else 0; return mapOf("isSupported" to true, "hasPolicyAccess" to hasPolicyAccess(context), "active" to active, "endsAtMillis" to if (active) ends else 0L, "remainingSeconds" to remaining) }
    private fun preferences(context: Context) = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
