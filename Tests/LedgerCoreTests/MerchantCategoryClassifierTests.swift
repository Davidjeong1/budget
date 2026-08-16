import XCTest
@testable import LedgerCore

final class MerchantCategoryClassifierTests: XCTestCase {

    func testCafeMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("스타벅스코리아"), .cafe)
        XCTAssertEqual(MerchantCategoryClassifier.classify("STARBUCKS 강남점"), .cafe)
        XCTAssertEqual(MerchantCategoryClassifier.classify("투썸플레이스"), .cafe)
    }

    func testFoodMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("배달의민족"), .food)
        XCTAssertEqual(MerchantCategoryClassifier.classify("교촌치킨 역삼점"), .food)
    }

    func testTransportMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("서울메트로"), .transport)
        XCTAssertEqual(MerchantCategoryClassifier.classify("GS칼텍스 셀프주유소"), .transport)
    }

    func testLivingMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("쿠팡"), .living)
        XCTAssertEqual(MerchantCategoryClassifier.classify("이마트 성수점"), .living)
    }

    func testShoppingMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("무신사 스토어"), .shopping)
        XCTAssertEqual(MerchantCategoryClassifier.classify("올리브영"), .shopping)
    }

    func testHousingMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("NETFLIX.COM"), .housing)
        XCTAssertEqual(MerchantCategoryClassifier.classify("도시가스 요금"), .housing)
    }

    func testSalaryIsIncome() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("월급 (머니컴퍼니)"), .salary)
        XCTAssertTrue(Category.salary.isIncome)
    }

    /// Short ASCII keywords are matched as whole words, so they must not swallow longer names that
    /// merely contain them.
    func testShortKeywordsMatchWholeWordsOnly() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("CU 역삼점"), .living)
        XCTAssertEqual(MerchantCategoryClassifier.classify("CUCKOO 전자"), .etc)
        XCTAssertEqual(MerchantCategoryClassifier.classify("KT 통신요금"), .housing)
        XCTAssertEqual(MerchantCategoryClassifier.classify("KTX 서울역"), .transport)
    }

    /// Card messages carry the branch inside the merchant name, so a keyword from another category
    /// is routinely sitting in a name that a longer keyword identifies exactly. The specific one
    /// has to win, or the purchase lands on a budget it never belonged to.
    func testBranchSuffixDoesNotStealTheCategory() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("GS25 강남버스터미널점"), .living)
        XCTAssertEqual(MerchantCategoryClassifier.classify("이마트24 지하철2호선역점"), .living)
        XCTAssertEqual(MerchantCategoryClassifier.classify("스타벅스 고속버스터미널점"), .cafe)
        XCTAssertEqual(MerchantCategoryClassifier.classify("올리브영 택시승강장점"), .shopping)
    }

    /// The longer keyword wins wherever two categories both match, so the table's order is no
    /// longer what decides the answer.
    func testMoreSpecificKeywordWins() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("쿠팡이츠"), .food)
        XCTAssertEqual(MerchantCategoryClassifier.classify("쿠팡"), .living)
        XCTAssertEqual(MerchantCategoryClassifier.classify("GS칼텍스 편의점"), .transport)
    }

    /// A row that is money out never gets an income category: 환급 filed under 급여 while the row is
    /// still an expense counts money that came back as money spent.
    func testExpenseSuggestionIsNeverAnIncomeCategory() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("카드 환급"), .salary)
        XCTAssertEqual(MerchantCategoryClassifier.expenseCategory(for: "카드 환급"), .etc)
        XCTAssertEqual(MerchantCategoryClassifier.expenseCategory(for: "스타벅스"), .cafe)
        XCTAssertEqual(MerchantCategoryClassifier.expenseCategory(for: nil), .etc)
    }

    func testUnknownAndBlankFallBackToEtc() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("무슨무슨상사"), .etc)
        XCTAssertEqual(MerchantCategoryClassifier.classify(nil), .etc)
        XCTAssertEqual(MerchantCategoryClassifier.classify("   "), .etc)
    }

    func testExpenseChipsExcludeIncome() {
        XCTAssertFalse(Category.expenseCases.contains(.salary))
        XCTAssertEqual(Category.expenseCases.count, 7)
    }
}
