import XCTest
@testable import LedgerParser

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
        XCTAssertEqual(MerchantCategoryClassifier.classify("카카오티 택시"), .transport)
        XCTAssertEqual(MerchantCategoryClassifier.classify("GS칼텍스 셀프주유소"), .transport)
    }

    func testShoppingMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("쿠팡"), .shopping)
        XCTAssertEqual(MerchantCategoryClassifier.classify("GS25 삼성점"), .shopping)
    }

    func testCultureMerchants() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("NETFLIX.COM"), .culture)
        XCTAssertEqual(MerchantCategoryClassifier.classify("CGV 왕십리"), .culture)
    }

    func testUnknownAndBlankFallBackToEtc() {
        XCTAssertEqual(MerchantCategoryClassifier.classify("무슨무슨상사"), .etc)
        XCTAssertEqual(MerchantCategoryClassifier.classify(nil), .etc)
        XCTAssertEqual(MerchantCategoryClassifier.classify("   "), .etc)
    }
}
