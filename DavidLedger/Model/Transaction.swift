import Foundation
import SwiftData
import LedgerCore

@Model
final class Transaction {
    var amount: Int
    var isExpense: Bool
    var merchant: String
    var categoryRaw: String
    var memo: String
    var occurredAt: Date

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .etc }
        set { categoryRaw = newValue.rawValue }
    }

    /// Signed for display and for summing: money out is negative, money in is positive.
    var signedAmount: Int { isExpense ? -amount : amount }

    init(
        amount: Int,
        isExpense: Bool = true,
        merchant: String,
        category: Category = .etc,
        memo: String = "",
        occurredAt: Date = .now
    ) {
        self.amount = amount
        self.isExpense = isExpense
        self.merchant = merchant
        self.categoryRaw = category.rawValue
        self.memo = memo
        self.occurredAt = occurredAt
    }
}
