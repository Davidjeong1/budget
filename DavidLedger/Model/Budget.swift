import Foundation
import SwiftData
import LedgerCore

/// A monthly spending target: one overall figure plus an optional per-category breakdown, matching
/// the 예산 설정 screen. Stored per month so changing this month's budget does not rewrite history.
@Model
final class Budget {
    /// First instant of the month this budget applies to — the natural unique key for a month.
    @Attribute(.unique) var monthStart: Date
    var totalTarget: Int
    /// Category raw value → target amount. Categories absent from the map have no target.
    var categoryTargets: [String: Int]

    init(monthStart: Date, totalTarget: Int, categoryTargets: [String: Int] = [:]) {
        self.monthStart = monthStart
        self.totalTarget = totalTarget
        self.categoryTargets = categoryTargets
    }

    func target(for category: Category) -> Int? {
        categoryTargets[category.rawValue]
    }

    func setTarget(_ amount: Int?, for category: Category) {
        if let amount, amount > 0 {
            categoryTargets[category.rawValue] = amount
        } else {
            categoryTargets.removeValue(forKey: category.rawValue)
        }
    }

    /// Categories with a target, ordered as they appear in `Category.allCases` so the budget list
    /// does not reshuffle when a target changes.
    var budgetedCategories: [Category] {
        Category.allCases.filter { categoryTargets[$0.rawValue] != nil }
    }
}
