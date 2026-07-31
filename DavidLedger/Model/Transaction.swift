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

    /// Signed for display and for summing: money out is negative, money in is positive.
    var signedAmount: Int { isExpense ? -amount : amount }

    /// The category is held as its raw key rather than a `Category`, because it may also name one
    /// of the user's own categories. `CategoryCatalog` turns the key into something displayable.
    init(
        amount: Int,
        isExpense: Bool = true,
        merchant: String,
        categoryRaw: String = Category.etc.rawValue,
        memo: String = "",
        occurredAt: Date = .now
    ) {
        self.amount = amount
        self.isExpense = isExpense
        self.merchant = merchant
        self.categoryRaw = categoryRaw
        self.memo = memo
        self.occurredAt = occurredAt
    }
}
