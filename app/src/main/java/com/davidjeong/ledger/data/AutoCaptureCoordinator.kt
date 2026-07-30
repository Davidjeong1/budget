package com.davidjeong.ledger.data

import android.content.Context
import android.util.Log
import com.davidjeong.ledger.data.local.LedgerDatabase
import com.davidjeong.ledger.data.repository.LedgerRepository
import com.davidjeong.ledger.notification.CaptureNotifier
import com.davidjeong.ledger.parser.PaymentMessageParser
import com.davidjeong.ledger.parser.PaymentSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Single entry point for both capture channels (SMS and KakaoTalk notifications). Owns its own
 * scope because its callers are a BroadcastReceiver and a NotificationListenerService, neither of
 * which has a lifecycle that outlives the short window they are given to hand off work.
 */
object AutoCaptureCoordinator {

    private const val TAG = "AutoCapture"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun submit(context: Context, text: String, source: PaymentSource) {
        val appContext = context.applicationContext
        if (!AutoCaptureSettings.isEnabled(appContext)) return
        if (!PaymentMessageParser.looksLikePaymentMessage(text)) return

        scope.launch {
            runCatching {
                val payment = PaymentMessageParser.parse(text, source) ?: return@runCatching
                val repository = LedgerRepository(LedgerDatabase.get(appContext).transactionDao())
                if (repository.recordAutoCaptured(payment)) {
                    CaptureNotifier.notifyCaptured(appContext, payment)
                }
            }.onFailure { Log.w(TAG, "결제 메시지 자동 반영에 실패했습니다", it) }
        }
    }
}
