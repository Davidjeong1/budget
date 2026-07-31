import Foundation
import LedgerCore

/// The monthly figures every screen reads. Computed in one place so the dashboard headline, the
/// donut and the budget bars cannot disagree about what a month's spending was.
struct MonthlyDigest {
    let month: MonthRange
    let transactions: [Transaction]

    init(month: MonthRange, allTransactions: [Transaction]) {
        self.month = month
        self.transactions = allTransactions.filter { month.contains($0.occurredAt) }
    }

    /// Expenses net of refunds — a negative-amount expense row is a cancellation and reduces the
    /// total rather than counting as income.
    var expenseTotal: Int {
        transactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    var incomeTotal: Int {
        transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    /// Spend per category, largest first. Categories that net to zero or less are dropped so they
    /// do not render as empty slices or bars.
    var categoryTotals: [(category: Category, total: Int)] {
        Dictionary(grouping: transactions.filter(\.isExpense), by: \.category)
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    func total(for category: Category) -> Int {
        transactions
            .filter { $0.isExpense && $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    /// Expense totals per week bucket, for the dashboard's trend chart.
    func weeklyTotals(now: Date = .now) -> [(label: String, total: Int, isCurrent: Bool)] {
        month.weekBuckets(now: now).map { bucket in
            let total = transactions
                .filter { $0.isExpense && bucket.range.contains($0.occurredAt) }
                .reduce(0) { $0 + $1.amount }
            return (bucket.label, max(total, 0), bucket.isCurrent)
        }
    }

    /// Transactions grouped into day sections, newest day first and newest row first within a day.
    var daySections: [(day: Date, net: Int, rows: [Transaction])] {
        let calendar = Calendar.current
        return Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.occurredAt) }
            .map { day, rows in
                (
                    day: day,
                    net: rows.reduce(0) { $0 + $1.signedAmount },
                    rows: rows.sorted { $0.occurredAt > $1.occurredAt }
                )
            }
            .sorted { $0.day > $1.day }
    }

    var recent: [Transaction] {
        Array(transactions.sorted { $0.occurredAt > $1.occurredAt }.prefix(4))
    }

    /// Share of `totalTarget` already spent, clamped so an overspent month still renders a full bar.
    func budgetUsage(target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(expenseTotal) / Double(target), 0), 1)
    }

    func budgetPercent(target: Int) -> Int {
        guard target > 0 else { return 0 }
        return Int((Double(expenseTotal) / Double(target) * 100).rounded())
    }
}
