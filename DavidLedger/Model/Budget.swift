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

    func target(forRaw raw: String) -> Int? {
        categoryTargets[raw]
    }

    func setTarget(_ amount: Int?, forRaw raw: String) {
        if let amount, amount > 0 {
            categoryTargets[raw] = amount
        } else {
            categoryTargets.removeValue(forKey: raw)
        }
    }

    /// The keys with a target, unordered — a dictionary has no order to offer. The budget screen
    /// sorts them through `CategoryCatalog`, which is the only place that knows where the user's
    /// own categories belong relative to the built-in ones.
    var budgetedRaws: [String] { Array(categoryTargets.keys) }
}
