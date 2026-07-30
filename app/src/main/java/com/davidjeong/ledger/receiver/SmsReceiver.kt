package com.davidjeong.ledger.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.davidjeong.ledger.data.AutoCaptureCoordinator
import com.davidjeong.ledger.parser.PaymentSource

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        // A single approval longer than one SMS part arrives as several PDUs that must be
        // rejoined before parsing, otherwise the amount and the merchant land in different parts.
        val body = messages.joinToString(separator = "") { it.displayMessageBody.orEmpty() }
        if (body.isBlank()) return

        AutoCaptureCoordinator.submit(context, body, PaymentSource.SMS)
    }
}
