package com.davidjeong.ledger.data

import android.content.Context

object AutoCaptureSettings {

    private const val PREFS = "auto_capture_settings"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_NOTIFY_ON_CAPTURE = "notify_on_capture"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun notifyOnCapture(context: Context): Boolean =
        prefs(context).getBoolean(KEY_NOTIFY_ON_CAPTURE, true)

    fun setNotifyOnCapture(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_NOTIFY_ON_CAPTURE, enabled).apply()
    }
}
