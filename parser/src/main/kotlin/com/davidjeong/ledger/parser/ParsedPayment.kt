package com.davidjeong.ledger.parser

/**
 * A payment approval fact extracted from an SMS or KakaoTalk notification.
 *
 * [approvedAt] is only populated when the source text itself carries a date/time
 * (banks usually include MM/dd HH:mm); callers should fall back to "now" otherwise.
 */
data class ParsedPayment(
    val amount: Long,
    val merchant: String?,
    val issuer: String?,
    val cardLast4: String?,
    val approvedAt: PartialDateTime?,
    val installmentMonths: Int?,
    val isCancellation: Boolean,
    val source: PaymentSource,
    val rawText: String,
)

data class PartialDateTime(
    val month: Int?,
    val day: Int?,
    val hour: Int?,
    val minute: Int?,
)

enum class PaymentSource {
    SMS,
    KAKAO_NOTIFICATION,
}
