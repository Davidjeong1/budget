package com.davidjeong.ledger.notification

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.davidjeong.ledger.MainActivity
import com.davidjeong.ledger.R
import com.davidjeong.ledger.data.AutoCaptureSettings
import com.davidjeong.ledger.parser.ParsedPayment
import com.davidjeong.ledger.util.toWon

/** Confirms to the user that a payment was auto-filed, so silent capture stays visible. */
object CaptureNotifier {

    private const val CHANNEL_ID = "auto_capture"

    fun notifyCaptured(context: Context, payment: ParsedPayment) {
        if (!AutoCaptureSettings.notifyOnCapture(context)) return
        if (!hasPostPermission(context)) return

        ensureChannel(context)

        val label = if (payment.isCancellation) "결제 취소가 반영되었습니다" else "결제 내역이 반영되었습니다"
        val merchant = payment.merchant ?: "미상 가맹점"

        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(label)
            .setContentText("$merchant · ${payment.amount.toWon()}")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        NotificationManagerCompat.from(context)
            .notify(payment.rawText.hashCode(), notification)
    }

    private fun hasPostPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "자동 가계부 반영",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "결제 문자를 가계부에 자동 반영했을 때 알려줍니다" },
        )
    }
}
