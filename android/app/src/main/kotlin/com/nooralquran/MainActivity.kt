package com.nooralquran

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.nooralquran/mosque_mode"
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result -> handleMethod(call, result) }
    }
    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "openPolicyAccessSettings" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)); result.success(null) }
                "openExactAlarmSettings" -> { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))); result.success(null) }
                "startSession" -> { val duration = call.argument<Int>("durationSeconds") ?: return result.error("INVALID_DURATION", "مدة الجلسة مطلوبة.", null); MosqueModeSession.begin(this, duration.coerceAtLeast(1)); result.success(MosqueModeSession.status(this)) }
                "cancelSession" -> { MosqueModeSession.cancel(this); result.success(MosqueModeSession.status(this)) }
                "scheduleSession" -> { val at = call.argument<Long>("atMillis") ?: return result.error("INVALID_TIME", "وقت الجلسة مطلوب.", null); val duration = call.argument<Int>("durationSeconds") ?: return result.error("INVALID_DURATION", "مدة الجلسة مطلوبة.", null); MosqueModeSession.schedule(this, at, duration.coerceAtLeast(1)); result.success(MosqueModeSession.status(this)) }
                "cancelScheduledSession" -> { MosqueModeSession.cancelScheduled(this); result.success(MosqueModeSession.status(this)) }
                "getSessionStatus" -> { MosqueModeSession.restoreIfExpired(this); result.success(MosqueModeSession.status(this)) }
                else -> result.notImplemented()
            }
        } catch (error: IllegalStateException) { result.error("SETTINGS_REQUIRED", error.message, null) }
        catch (error: SecurityException) { result.error("POLICY_ACCESS_REQUIRED", "امنح التطبيق الصلاحيات المطلوبة من إعدادات Android.", null) }
        catch (error: Exception) { result.error("MOSQUE_MODE_ERROR", error.message, null) }
    }
}
