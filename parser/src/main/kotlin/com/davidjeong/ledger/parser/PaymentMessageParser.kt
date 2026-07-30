package com.davidjeong.ledger.parser

/**
 * Parses Korean bank / card-company / simple-pay approval texts, whether they arrived as
 * an SMS or as a KakaoTalk 알림톡 (AlimTalk) notification from a card company's official
 * channel — both use the same free-text approval-message conventions, so one parser
 * serves both sources.
 *
 * This is intentionally a set of tolerant heuristics rather than a strict grammar: real
 * messages vary bank to bank, so every extractor degrades gracefully (returns null) instead
 * of throwing, and [parse] only requires an amount to produce a result.
 */
object PaymentMessageParser {

    private val AMOUNT_REGEX = Regex("(\\d{1,3}(?:,\\d{3})+|\\d+)\\s*원")
    private val AMOUNT_CONTEXT_EXCLUDE = listOf("누적", "잔액", "한도", "포인트", "적립", "캐시백")

    private val DATE_TIME_REGEX = Regex("(\\d{1,2})/(\\d{1,2})\\s+(\\d{1,2}):(\\d{2})")
    private val CARD_LAST4_REGEX = Regex("\\((\\d{4})\\)")
    private val INSTALLMENT_REGEX = Regex("(\\d{1,2})\\s*개월(?:\\s*할부)?")
    private val CANCELLATION_REGEX = Regex("승인\\s*취소|결제\\s*취소|취소\\s*완료")
    private val APPROVAL_KEYWORDS = listOf("승인", "결제", "체크승인")

    private val KNOWN_ISSUERS = listOf(
        "KB국민카드", "국민카드", "신한카드", "삼성카드", "우리카드", "하나카드",
        "롯데카드", "현대카드", "NH농협카드", "농협카드", "비씨카드", "BC카드",
        "씨티카드", "카카오페이", "네이버페이", "토스", "페이코",
    ).sortedByDescending { it.length }

    private val MERCHANT_STOP_TOKENS = setOf(
        "카드", "앱카드", "승인", "정상승인", "체크승인", "정상", "체크카드", "해외", "국내", "일시불",
        "완료", "결제", "결제완료", "취소", "포인트", "적립", "누적", "잔액", "한도",
        "web발신", "웹발신", "총누적",
    )

    /** Cheap pre-filter so callers (SMS/notification listeners) skip obviously irrelevant text. */
    fun looksLikePaymentMessage(text: String): Boolean {
        val hasApprovalKeyword = APPROVAL_KEYWORDS.any { text.contains(it) }
        val hasWonAmount = AMOUNT_REGEX.containsMatchIn(text)
        return hasApprovalKeyword && hasWonAmount
    }

    fun parse(text: String, source: PaymentSource = PaymentSource.SMS): ParsedPayment? {
        if (!looksLikePaymentMessage(text)) return null

        val amountMatch = findAmountMatch(text) ?: return null
        val amount = amountMatch.groupValues[1].replace(",", "").toLongOrNull() ?: return null

        val dateTimeMatch = DATE_TIME_REGEX.find(text)
        val issuer = KNOWN_ISSUERS.firstOrNull { text.contains(it) }

        return ParsedPayment(
            amount = amount,
            merchant = extractMerchant(text, dateTimeMatch, amountMatch.range),
            issuer = issuer,
            cardLast4 = CARD_LAST4_REGEX.find(text)?.groupValues?.get(1),
            approvedAt = dateTimeMatch?.let {
                PartialDateTime(
                    month = it.groupValues[1].toIntOrNull(),
                    day = it.groupValues[2].toIntOrNull(),
                    hour = it.groupValues[3].toIntOrNull(),
                    minute = it.groupValues[4].toIntOrNull(),
                )
            },
            installmentMonths = if (text.contains("일시불")) null else {
                INSTALLMENT_REGEX.find(text)?.groupValues?.get(1)?.toIntOrNull()
            },
            isCancellation = CANCELLATION_REGEX.containsMatchIn(text),
            source = source,
            rawText = text,
        )
    }

    private fun findAmountMatch(text: String): MatchResult? {
        for (match in AMOUNT_REGEX.findAll(text)) {
            val contextStart = maxOf(0, match.range.first - 10)
            val context = text.substring(contextStart, match.range.first)
            if (AMOUNT_CONTEXT_EXCLUDE.any { context.contains(it) }) continue
            return match
        }
        return null
    }

    private fun extractMerchant(
        text: String,
        dateTimeMatch: MatchResult?,
        amountRange: IntRange,
    ): String? {
        // Most bank SMS put the merchant right after the date/time stamp, on the same segment.
        if (dateTimeMatch != null) {
            val after = text.substring(dateTimeMatch.range.last + 1)
            val segment = after.substringBefore('\n').trim()
            cleanMerchantCandidate(segment)?.let { return it }
        }

        // Simple-pay formats (KakaoPay/Toss) often put the merchant before the amount, same line.
        val lineStart = text.lastIndexOf('\n', amountRange.first).let { if (it < 0) 0 else it + 1 }
        val before = text.substring(lineStart, amountRange.first)
        cleanMerchantCandidate(before)?.let { return it }

        // Fall back to scanning every line for the last non-noise candidate.
        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
        for (line in lines.asReversed()) {
            val candidate = cleanMerchantCandidate(line)
            if (candidate != null && candidate.length in 2..40) return candidate
        }
        return null
    }

    private fun cleanMerchantCandidate(raw: String): String? {
        var s = raw
        s = s.replace(Regex("\\[[^\\]]*]"), " ")
        s = s.replace(CARD_LAST4_REGEX, " ")
        s = s.replace(DATE_TIME_REGEX, " ")
        s = s.replace(AMOUNT_REGEX, " ")
        s = s.replace(INSTALLMENT_REGEX, " ")

        val tokens = s.split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .filterNot { token -> KNOWN_ISSUERS.any { token.equals(it, ignoreCase = true) } }
            .filterNot { token -> MERCHANT_STOP_TOKENS.any { token.equals(it, ignoreCase = true) } }
            .filterNot { it.endsWith("님") }
            .filterNot { Regex("^\\d+$").matches(it) }

        val result = tokens.joinToString(" ").trim()
        return result.ifBlank { null }
    }
}
