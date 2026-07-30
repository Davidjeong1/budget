import Foundation

/// A payment approval fact extracted from a message.
///
/// `approvedAt` is only populated when the source text itself carries a date/time (Korean card
/// messages usually include MM/dd HH:mm); callers should fall back to "now" otherwise.
public struct ParsedPayment: Equatable, Sendable {
    public let amount: Int
    public let merchant: String?
    public let issuer: String?
    public let cardLast4: String?
    public let approvedAt: PartialDateTime?
    public let installmentMonths: Int?
    public let isCancellation: Bool
    public let source: PaymentSource
    public let rawText: String

    public init(
        amount: Int,
        merchant: String?,
        issuer: String?,
        cardLast4: String?,
        approvedAt: PartialDateTime?,
        installmentMonths: Int?,
        isCancellation: Bool,
        source: PaymentSource,
        rawText: String
    ) {
        self.amount = amount
        self.merchant = merchant
        self.issuer = issuer
        self.cardLast4 = cardLast4
        self.approvedAt = approvedAt
        self.installmentMonths = installmentMonths
        self.isCancellation = isCancellation
        self.source = source
        self.rawText = rawText
    }
}

public struct PartialDateTime: Equatable, Sendable {
    public let month: Int?
    public let day: Int?
    public let hour: Int?
    public let minute: Int?

    public init(month: Int?, day: Int?, hour: Int?, minute: Int?) {
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }
}

public enum PaymentSource: String, Codable, Sendable {
    /// Handed to the app by a Shortcuts automation triggered on an incoming message.
    case shortcutAutomation
    /// Handed to the app through the share sheet.
    case shareSheet
    /// Typed in by the user.
    case manual
}
