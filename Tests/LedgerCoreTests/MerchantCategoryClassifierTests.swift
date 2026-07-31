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
