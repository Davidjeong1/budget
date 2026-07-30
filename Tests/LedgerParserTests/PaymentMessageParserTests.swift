import XCTest
@testable import LedgerParser

final class PaymentMessageParserTests: XCTestCase {

    func testShinhanCardMultiLineApprovalIsParsed() throws {
        let text = """
        [Web발신]
        신한카드(1234)승인
        다비드님 12,000원 일시불
        07/30 14:23
        스타벅스코리아
        누적 350,000원
        """

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 12_000)
        XCTAssertEqual(result.issuer, "신한카드")
        XCTAssertEqual(result.cardLast4, "1234")
        XCTAssertEqual(result.merchant, "스타벅스코리아")
        XCTAssertEqual(result.approvedAt, PartialDateTime(month: 7, day: 30, hour: 14, minute: 23))
        XCTAssertNil(result.installmentMonths)
        XCTAssertFalse(result.isCancellation)
    }

    func testKookminCardSingleLineApprovalIsParsed() throws {
        let text = "[Web발신]KB국민카드 승인 다비드님 12,300원 일시불 07/30 14:23 스타벅스 정상승인"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 12_300)
        XCTAssertEqual(result.issuer, "KB국민카드")
        XCTAssertEqual(result.merchant, "스타벅스")
        XCTAssertNil(result.installmentMonths)
    }

    func testSamsungCardInstallmentIsParsed() throws {
        let text = "[삼성카드]승인 다비드님 33,000원(3개월) 07/30 14:23 스타벅스코리아 삼성카드 앱카드"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 33_000)
        XCTAssertEqual(result.issuer, "삼성카드")
        XCTAssertEqual(result.installmentMonths, 3)
        XCTAssertEqual(result.merchant, "스타벅스코리아")
    }

    func testCumulativeAmountIsNotMistakenForPaymentAmount() throws {
        let text = "우리카드승인 다비드 33,000원 일시불 07/30 14:00 스타벅스 총누적 100,000원"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 33_000)
        XCTAssertEqual(result.issuer, "우리카드")
    }

    func testBalanceAmountIsNotMistakenForPaymentAmount() throws {
        let text = "국민카드 체크승인 다비드님 12,000원 07/30 14:23 스타벅스 잔액 500,000원"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 12_000)
    }

    func testKakaoPayApprovalIsParsed() throws {
        let text = """
        [카카오페이]
        스타벅스코리아 12,000원 결제 완료
        07/30 14:23
        """

        let result = try XCTUnwrap(PaymentMessageParser.parse(text, source: .shareSheet))

        XCTAssertEqual(result.amount, 12_000)
        XCTAssertEqual(result.issuer, "카카오페이")
        XCTAssertEqual(result.merchant, "스타벅스코리아")
        XCTAssertEqual(result.source, .shareSheet)
    }

    func testTossApprovalIsParsed() throws {
        let text = "[토스] 12,000원 승인 스타벅스코리아 07/30 14:23"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 12_000)
        XCTAssertEqual(result.issuer, "토스")
        XCTAssertEqual(result.merchant, "스타벅스코리아")
    }

    func testCancellationIsFlagged() throws {
        let text = "신한카드(1234)승인취소 12,000원 07/30 15:00 스타벅스코리아"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertTrue(result.isCancellation)
        XCTAssertEqual(result.amount, 12_000)
    }

    /// The issuer is glued to the keyword and there is no date/time, so merchant extraction has to
    /// fall through to the line scan and still not leak "우리카드승인" into the merchant name.
    func testIssuerGluedToKeywordIsNotPartOfMerchant() throws {
        let text = "우리카드승인 33,000원 스타벅스코리아"

        let result = try XCTUnwrap(PaymentMessageParser.parse(text))

        XCTAssertEqual(result.amount, 33_000)
        XCTAssertEqual(result.issuer, "우리카드")
        XCTAssertEqual(result.merchant, "스타벅스코리아")
    }

    func testUnrelatedChatMessageIsNotParsed() {
        XCTAssertNil(PaymentMessageParser.parse("오늘 저녁 뭐 먹을까요? 스타벅스에서 이따 봐요"))
    }

    func testLooksLikePaymentMessageFiltersNonPayments() {
        XCTAssertFalse(PaymentMessageParser.looksLikePaymentMessage("내일 회의 몇시에요?"))
        XCTAssertTrue(
            PaymentMessageParser.looksLikePaymentMessage("신한카드(1234)승인 12,000원 07/30 14:23 스타벅스코리아")
        )
    }
}
