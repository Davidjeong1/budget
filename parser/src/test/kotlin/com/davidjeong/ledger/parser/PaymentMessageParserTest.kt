package com.davidjeong.ledger.parser

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class PaymentMessageParserTest {

    @Test
    fun `shinhan card multi-line approval is parsed`() {
        val text = """
            [Web발신]
            신한카드(1234)승인
            다비드님 12,000원 일시불
            07/30 14:23
            스타벅스코리아
            누적 350,000원
        """.trimIndent()

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertEquals(12_000L, result.amount)
        assertEquals("신한카드", result.issuer)
        assertEquals("1234", result.cardLast4)
        assertEquals("스타벅스코리아", result.merchant)
        assertEquals(PartialDateTime(7, 30, 14, 23), result.approvedAt)
        assertNull(result.installmentMonths)
        assertFalse(result.isCancellation)
    }

    @Test
    fun `kb kookmin card single line approval is parsed`() {
        val text = "[Web발신]KB국민카드 승인 다비드님 12,300원 일시불 07/30 14:23 스타벅스 정상승인"

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertEquals(12_300L, result.amount)
        assertEquals("KB국민카드", result.issuer)
        assertEquals("스타벅스", result.merchant)
        assertNull(result.installmentMonths)
    }

    @Test
    fun `samsung card single line with installment is parsed`() {
        val text = "[삼성카드]승인 다비드님 33,000원(3개월) 07/30 14:23 스타벅스코리아 삼성카드 앱카드"

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertEquals(33_000L, result.amount)
        assertEquals("삼성카드", result.issuer)
        assertEquals(3, result.installmentMonths)
        assertEquals("스타벅스코리아", result.merchant)
    }

    @Test
    fun `woori card cumulative amount is not mistaken for payment amount`() {
        val text = "우리카드승인 다비드 33,000원 일시불 07/30 14:00 스타벅스 총누적 100,000원"

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertEquals(33_000L, result.amount)
        assertEquals("우리카드", result.issuer)
    }

    @Test
    fun `kakaopay multi-line approval is parsed`() {
        val text = """
            [카카오페이]
            스타벅스코리아 12,000원 결제 완료
            07/30 14:23
        """.trimIndent()

        val result = PaymentMessageParser.parse(text, PaymentSource.KAKAO_NOTIFICATION)

        assertNotNull(result)
        assertEquals(12_000L, result.amount)
        assertEquals("카카오페이", result.issuer)
        assertEquals("스타벅스코리아", result.merchant)
        assertEquals(PaymentSource.KAKAO_NOTIFICATION, result.source)
    }

    @Test
    fun `toss single line approval is parsed`() {
        val text = "[토스] 12,000원 승인 스타벅스코리아 07/30 14:23"

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertEquals(12_000L, result.amount)
        assertEquals("토스", result.issuer)
        assertEquals("스타벅스코리아", result.merchant)
    }

    @Test
    fun `cancellation message is flagged`() {
        val text = "신한카드(1234)승인취소 12,000원 07/30 15:00 스타벅스코리아"

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertTrue(result.isCancellation)
        assertEquals(12_000L, result.amount)
    }

    @Test
    fun `check card debit approval ignores balance amount`() {
        val text = "국민카드 체크승인 다비드님 12,000원 07/30 14:23 스타벅스 잔액 500,000원"

        val result = PaymentMessageParser.parse(text)

        assertNotNull(result)
        assertEquals(12_000L, result.amount)
    }

    @Test
    fun `unrelated chat message is not parsed as a payment`() {
        val text = "오늘 저녁 뭐 먹을까요? 스타벅스에서 이따 봐요"

        val result = PaymentMessageParser.parse(text)

        assertNull(result)
    }

    @Test
    fun `looksLikePaymentMessage is a cheap true negative filter`() {
        assertFalse(PaymentMessageParser.looksLikePaymentMessage("내일 회의 몇시에요?"))
        assertTrue(
            PaymentMessageParser.looksLikePaymentMessage(
                "신한카드(1234)승인 12,000원 07/30 14:23 스타벅스코리아",
            ),
        )
    }
}
