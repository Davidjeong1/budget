import Foundation
import SwiftData
import LedgerParser

@Model
final class Transaction {
    /// Identifies the underlying approval, so re-running a Shortcuts automation or sharing the
    /// same message twice cannot file one payment as two entries. Manual entries get a random key
    /// because they are always allowed to repeat — a non-optional key keeps the uniqueness
    /// constraint well defined instead of relying on how nil compares.
    @Attribute(.unique) var dedupeKey: String

    /// Negative for a cancellation, so a refund nets against the original approval in the monthly
    /// total instead of showing up as income.
    var amount: Int
    var isExpense: Bool
    var merchant: String
    var categoryRaw: String
    var memo: String
    var occurredAt: Date
    var issuer: String?
    var cardLast4: String?
    var installmentMonths: Int?
    var isAutoCaptured: Bool
    var rawMessage: String?

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
        occurredAt: Date = .now,
        issuer: String? = nil,
        cardLast4: String? = nil,
        installmentMonths: Int? = nil,
        isAutoCaptured: Bool = false,
        rawMessage: String? = nil,
        dedupeKey: String = UUID().uuidString
    ) {
        self.amount = amount
        self.isExpense = isExpense
        self.merchant = merchant
        self.categoryRaw = category.rawValue
        self.memo = memo
        self.occurredAt = occurredAt
        self.issuer = issuer
        self.cardLast4 = cardLast4
        self.installmentMonths = installmentMonths
        self.isAutoCaptured = isAutoCaptured
        self.rawMessage = rawMessage
        self.dedupeKey = dedupeKey
    }
}
