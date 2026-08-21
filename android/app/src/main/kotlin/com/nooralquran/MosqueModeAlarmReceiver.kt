package com.nooralquran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MosqueModeAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == actionStart) MosqueModeSession.startScheduledSession(context)
    }
    companion object { const val actionStart = "com.nooralquran.START_SCHEDULED_MOSQUE_MODE" }
}
