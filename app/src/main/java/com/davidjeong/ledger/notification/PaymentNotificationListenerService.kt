package com.davidjeong.ledger.notification

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.davidjeong.ledger.data.AutoCaptureCoordinator
import com.davidjeong.ledger.parser.PaymentSource

/**
 * Reads card-approval 알림톡 messages that arrive through KakaoTalk. Card companies send the same
 * approval text there as they do over SMS, so the notification body goes through the same parser.
 */
class PaymentNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in WATCHED_PACKAGES) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()

        // KakaoTalk truncates the collapsed body, so prefer the expanded text when present;
        // the title carries the sending channel name, which the parser uses to spot the issuer.
        val body = bigText.ifBlank { text }
        if (body.isBlank()) return

        AutoCaptureCoordinator.submit(
            this,
            listOf(title, body).filter { it.isNotBlank() }.joinToString("\n"),
            PaymentSource.KAKAO_NOTIFICATION,
        )
    }

    private companion object {
        val WATCHED_PACKAGES = setOf("com.kakao.talk")
    }
}
