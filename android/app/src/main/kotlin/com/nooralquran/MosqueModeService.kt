package com.nooralquran

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationCompat
import java.util.Locale

class MosqueModeService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var finishRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels()
        if (intent?.action == actionCancel) finishSession(false) else resumeSession()
        return START_STICKY
    }

    override fun onDestroy() { finishRunnable?.let(handler::removeCallbacks); finishRunnable = null; super.onDestroy() }

    private fun resumeSession() {
        val status = MosqueModeSession.status(this)
        if (status["active"] != true) {
            if (MosqueModeSession.hasStoredSession(this)) finishSession(true) else stopSelf()
            return
        }
        val endsAtMillis = status["endsAtMillis"] as Long
        startForeground(foregroundNotificationId, sessionNotification(endsAtMillis))
        finishRunnable?.let(handler::removeCallbacks)
        finishRunnable = Runnable { finishSession(true) }
        handler.postDelayed(finishRunnable!!, (endsAtMillis - System.currentTimeMillis()).coerceAtLeast(0L))
    }

    private fun finishSession(announce: Boolean) {
        val hadActiveSession = MosqueModeSession.hasStoredSession(this)
        MosqueModeSession.restore(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        if (announce && hadActiveSession) { completionNotification(); speakCompletionMessage() }
        stopSelf()
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(sessionChannel, "وضع الجامع", NotificationManager.IMPORTANCE_LOW).apply { description = "إشعار جلسة وضع الجامع المؤقتة"; setSound(null, null) })
        manager.createNotificationChannel(NotificationChannel(completionChannel, "انتهاء وضع الجامع", NotificationManager.IMPORTANCE_HIGH).apply { description = "تنبيه انتهاء وضع الجامع" })
    }

    private fun sessionNotification(endsAtMillis: Long) = NotificationCompat.Builder(this, sessionChannel)
        .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
        .setContentTitle("وضع الجامع مفعّل")
        .setContentText("سيُعاد إعداد عدم الإزعاج السابق عند انتهاء الجلسة.")
        .setOngoing(true)
        .setWhen(endsAtMillis)
        .setShowWhen(false)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .addAction(0, "إلغاء وضع الجامع", PendingIntent.getService(this, 0, Intent(this, MosqueModeService::class.java).setAction(actionCancel), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        .build()

    private fun completionNotification() {
        val notification = NotificationCompat.Builder(this, completionChannel)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
            .setContentTitle("انتهى وضع الجامع")
            .setContentText("تم إيقاف وضع الصامت وعاد الهاتف إلى الإعداد السابق.")
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(completionNotificationId, notification)
    }

    private fun speakCompletionMessage() {
        var speaker: TextToSpeech? = null
        speaker = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                speaker?.language = Locale("ar")
                speaker?.speak("عزيزي، تم إيقاف وضع الصامت. شكرًا لك لاستخدام تطبيقنا.", TextToSpeech.QUEUE_FLUSH, null, "mosque-mode-complete")
                Handler(Looper.getMainLooper()).postDelayed({ speaker?.shutdown() }, 10000)
            } else speaker?.shutdown()
        }
    }

    companion object {
        const val actionResume = "com.nooralquran.RESUME"
        const val actionCancel = "com.nooralquran.CANCEL"
        private const val foregroundNotificationId = 4201
        private const val completionNotificationId = 4202
        private const val sessionChannel = "mosque_mode_session"
        private const val completionChannel = "mosque_mode_completion"
    }
}
