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
    /// When on, every later month without a budget of its own uses this one — set once, repeat
    /// until changed. A later month that is edited gets its own row (see `effective(for:among:)`),
    /// so the change applies from that month on and never reaches back into earlier ones.
    ///
    /// Defaulted so stores written before this property existed migrate without a step of their own.
    var repeatsMonthly: Bool = false

    init(monthStart: Date, totalTarget: Int, categoryTargets: [String: Int] = [:], repeatsMonthly: Bool = false) {
        self.monthStart = monthStart
        self.totalTarget = totalTarget
        self.categoryTargets = categoryTargets
        self.repeatsMonthly = repeatsMonthly
    }

    /// The budget that applies to the month starting at `monthStart`: that month's own row if it
    /// has one, otherwise the nearest earlier row when that row repeats monthly. The nearest row
    /// decides on its own — one that stopped repeating ends the chain even if an older one repeats.
    static func effective(for monthStart: Date, among budgets: [Budget]) -> Budget? {
        let latest = budgets
            .filter { $0.monthStart <= monthStart }
            .max { $0.monthStart < $1.monthStart }
        guard let latest else { return nil }
        return latest.monthStart == monthStart || latest.repeatsMonthly ? latest : nil
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
