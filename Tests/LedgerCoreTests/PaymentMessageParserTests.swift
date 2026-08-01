import XCTest
@testable import LedgerCore

/// The carriers do not publish these layouts and none of them agree, so these are the shapes the
/// parser is known to handle. A new one that shows up in the wild belongs here first.
final class PaymentMessageParserTests: XCTestCase {

    func testMultiLineApproval() {
        let message = PaymentMessageParser.parse(
            """
            [Web발신]
            신한카드(1234)승인 홍길동
            5,500원 일시불
            07/31 14:23
            스타벅스강남점
            """
        )

        XCTAssertEqual(message?.amount, 5_500)
        XCTAssertEqual(message?.merchant, "스타벅스강남점")
        XCTAssertEqual(message?.isCancellation, false)
        XCTAssertEqual(message?.month, 7)
        XCTAssertEqual(message?.day, 31)
        XCTAssertEqual(message?.hour, 14)
        XCTAssertEqual(message?.minute, 23)
    }

    /// The accumulated total trails the charge and is the larger of the two, so taking the largest
    /// amount in the message would file the month's spending as a single transaction.
    func testRunningTotalIsNotTheCharge() {
        let message = PaymentMessageParser.parse(
            """
            KB국민카드 홍*동
            07/31 12:05
            12,000원
            스타벅스
            누적 350,000원
            """
        )

        XCTAssertEqual(message?.amount, 12_000)
        XCTAssertEqual(message?.merchant, "스타벅스")
    }

    func testSingleLineApprovalTakesTheMerchantAfterTheTimestamp() {
        let message = PaymentMessageParser.parse(
            "[Web발신] 삼성카드 승인 5,500원 일시불 07/31 14:23 스타벅스강남점"
        )

        XCTAssertEqual(message?.amount, 5_500)
        XCTAssertEqual(message?.merchant, "스타벅스강남점")
    }

    /// Reported rather than acted on: flipping the sign automatically would write a wrong row when
    /// the guess is wrong, and the user is looking at the confirmation screen anyway.
    func testCancellationIsFlagged() {
        let message = PaymentMessageParser.parse(
            """
            [Web발신]
            신한카드(1234)취소 홍길동
            5,500원
            07/31 15:00
            스타벅스강남점
            """
        )

        XCTAssertEqual(message?.isCancellation, true)
        XCTAssertEqual(message?.amount, 5_500)
    }

    /// A merchant name may carry digits, and 원 is a letter, so neither test alone separates a name
    /// line from an amount line.
    func testMerchantWithDigitsSurvives() {
        let message = PaymentMessageParser.parse(
            """
            [Web발신]
            현대카드 승인
            3,200원
            08/01 09:10
            GS25 역삼점
            """
        )

        XCTAssertEqual(message?.amount, 3_200)
        XCTAssertEqual(message?.merchant, "GS25 역삼점")
        // The whole point of reading the merchant out: the existing classifier takes it from here.
        XCTAssertEqual(MerchantCategoryClassifier.classify(message?.merchant), .living)
    }

    func testCardNumberIsNotReadAsADate() {
        let message = PaymentMessageParser.parse(
            """
            [Web발신]
            우리카드(9876)승인
            8,900원
            12/25 19:40
            교촌치킨
            """
        )

        XCTAssertEqual(message?.month, 12)
        XCTAssertEqual(message?.day, 25)
        XCTAssertEqual(message?.merchant, "교촌치킨")
    }

    func testNoAmountMeansNothingToRecord() {
        XCTAssertNil(PaymentMessageParser.parse("안녕하세요, 오늘 점심 같이 드실래요?"))
        XCTAssertNil(PaymentMessageParser.parse(""))
        // A balance notice on its own is not a purchase.
        XCTAssertNil(PaymentMessageParser.parse("누적 350,000원"))
    }

    // MARK: - Dating a message that carries no year

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testMessageIsDatedInTheCurrentYear() {
        let message = PaymentMessage(amount: 5_500, merchant: nil, isCancellation: false,
                                     month: 7, day: 31, hour: 14, minute: 23)

        XCTAssertEqual(
            message.occurredAt(now: date(2026, 8, 1, 9, 0), calendar: calendar),
            date(2026, 7, 31, 14, 23)
        )
    }

    /// Read on New Year's Day, a December message is from last year — dating it forward would file
    /// it eleven months into the future and hide it from every screen.
    func testDecemberMessageReadInJanuaryRollsBackAYear() {
        let message = PaymentMessage(amount: 5_500, merchant: nil, isCancellation: false,
                                     month: 12, day: 31, hour: 23, minute: 50)

        XCTAssertEqual(
            message.occurredAt(now: date(2026, 1, 1, 0, 10), calendar: calendar),
            date(2025, 12, 31, 23, 50)
        )
    }

    /// Midday rather than midnight, so the row cannot slide into the previous day.
    func testMissingTimeFallsBackToMidday() {
        let message = PaymentMessage(amount: 5_500, merchant: nil, isCancellation: false,
                                     month: 7, day: 31)

        XCTAssertEqual(
            message.occurredAt(now: date(2026, 8, 1), calendar: calendar),
            date(2026, 7, 31, 12, 0)
        )
    }

    func testMessageWithoutADateHasNoDate() {
        let message = PaymentMessage(amount: 5_500, merchant: "스타벅스", isCancellation: false)

        XCTAssertNil(message.occurredAt(now: date(2026, 8, 1), calendar: calendar))
    }

    /// The amount is the only field worth failing over; a message with nothing name-shaped in it
    /// still fills the figure in.
    func testAmountWithoutAMerchant() {
        let message = PaymentMessageParser.parse("5,500원 결제되었습니다")

        XCTAssertEqual(message?.amount, 5_500)
        XCTAssertNil(message?.merchant)
    }
}
