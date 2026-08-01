import XCTest
@testable import LedgerCore

final class BudgetPaceTests: XCTestCase {

    func testRunsOutMidMonthAtCurrentRate() {
        // 10일에 20만원 = 하루 2만원. 50만원 예산은 25일차에 소진된다.
        let pace = BudgetPace.projected(spent: 200_000, target: 500_000, elapsedDays: 10, totalDays: 31)
        XCTAssertEqual(pace, .runsOut(day: 25, projectedTotal: 620_000))
    }

    func testWithinBudgetWhenThePaceNeverReachesTheTarget() {
        // 하루 1만원이면 31일에 31만원, 50만원 예산 안에 들어온다.
        let pace = BudgetPace.projected(spent: 100_000, target: 500_000, elapsedDays: 10, totalDays: 31)
        XCTAssertEqual(pace, .withinBudget(projectedTotal: 310_000))
    }

    func testExceededTakesPrecedenceOverAnyProjection() {
        XCTAssertEqual(
            BudgetPace.projected(spent: 500_000, target: 500_000, elapsedDays: 10, totalDays: 31),
            .exceeded
        )
        XCTAssertEqual(
            BudgetPace.projected(spent: 600_000, target: 500_000, elapsedDays: 10, totalDays: 31),
            .exceeded
        )
    }

    /// A projection drawn from no spending at all is a line through the origin: it would always
    /// report that the budget lasts forever, which is worse than saying nothing.
    func testNothingToProjectYet() {
        XCTAssertNil(BudgetPace.projected(spent: 0, target: 500_000, elapsedDays: 10, totalDays: 31))
        XCTAssertNil(BudgetPace.projected(spent: 200_000, target: 0, elapsedDays: 10, totalDays: 31))
        XCTAssertNil(BudgetPace.projected(spent: 200_000, target: 500_000, elapsedDays: 0, totalDays: 31))
    }

    /// Spending everything on the first day should call the same day, not day zero or day two.
    func testExhaustionOnTheFirstDay() {
        let pace = BudgetPace.projected(spent: 400_000, target: 500_000, elapsedDays: 1, totalDays: 30)
        XCTAssertEqual(pace, .runsOut(day: 2, projectedTotal: 12_000_000))
    }

    /// A transaction dated into the future would otherwise divide the spend by more days than the
    /// month holds and understate the rate.
    func testElapsedDaysBeyondTheMonthDoNotFlattenTheRate() {
        let pace = BudgetPace.projected(spent: 310_000, target: 500_000, elapsedDays: 40, totalDays: 31)
        XCTAssertEqual(pace, .withinBudget(projectedTotal: 310_000))
    }
}
