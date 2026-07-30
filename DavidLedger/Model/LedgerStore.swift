import Foundation
import SwiftData
import LedgerParser

enum LedgerStoreError: Error {
    case notAPaymentMessage
    case duplicate
}

/// The one place that turns a parsed message into a stored entry. The app, the App Intent and the
/// share extension all go through here, so they cannot drift apart on dedupe or categorisation.
enum LedgerStore {

    /// Shared by the app and its extensions. Must match the App Group capability on every target.
    static let appGroupID = "group.com.davidjeong.ledger"

    static func makeSharedContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: Transaction.self, configurations: configuration)
    }

    /// Parses `text` and stores it. Throws `.duplicate` if this approval was already recorded,
    /// which is the normal outcome when a message gets shared or re-processed twice.
    @discardableResult
    static func record(
        messageText: String,
        source: PaymentSource,
        in context: ModelContext,
        now: Date = .now
    ) throws -> Transaction {
        guard let payment = PaymentMessageParser.parse(messageText, source: source) else {
            throw LedgerStoreError.notAPaymentMessage
        }

        let occurredAt = payment.approvedAt.resolveDate(now: now)
        let merchant = payment.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedMerchant = (merchant?.isEmpty == false) ? merchant! : "미상 가맹점"
        let key = dedupeKey(for: payment, occurredAt: occurredAt, merchant: resolvedMerchant)

        if try alreadyStored(key: key, in: context) {
            throw LedgerStoreError.duplicate
        }

        let transaction = Transaction(
            amount: payment.isCancellation ? -payment.amount : payment.amount,
            isExpense: true,
            merchant: resolvedMerchant,
            category: MerchantCategoryClassifier.classify(payment.merchant),
            occurredAt: occurredAt,
            issuer: payment.issuer,
            cardLast4: payment.cardLast4,
            installmentMonths: payment.installmentMonths,
            isAutoCaptured: true,
            rawMessage: payment.rawText,
            dedupeKey: key
        )
        context.insert(transaction)
        try context.save()
        return transaction
    }

    private static func alreadyStored(key: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.dedupeKey == key }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).isEmpty == false
    }

    /// Deliberately excludes the source channel and the raw text, so the same approval collapses
    /// onto one key however it reached the app. The timestamp is bucketed to the minute because
    /// two deliveries of one payment can disagree by a few seconds.
    private static func dedupeKey(
        for payment: ParsedPayment,
        occurredAt: Date,
        merchant: String
    ) -> String {
        let minuteBucket = Int(occurredAt.timeIntervalSince1970 / 60)
        return [
            String(payment.amount),
            merchant,
            payment.cardLast4 ?? "",
            String(payment.isCancellation),
            String(minuteBucket),
        ].joined(separator: "|")
    }
}

extension Optional where Wrapped == PartialDateTime {
    /// Card messages carry only MM/dd HH:mm, so the year is inferred. A date more than a day in
    /// the future means the message is really from last December being read in January, so the
    /// year rolls back rather than filing the payment eleven months ahead.
    func resolveDate(now: Date = .now, calendar: Calendar = .current) -> Date {
        guard let self, let month = self.month, let day = self.day else { return now }

        var components = calendar.dateComponents([.year], from: now)
        components.month = month
        components.day = day
        components.hour = self.hour ?? 0
        components.minute = self.minute ?? 0

        guard let candidate = calendar.date(from: components) else { return now }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), candidate > tomorrow {
            return calendar.date(byAdding: .year, value: -1, to: candidate) ?? candidate
        }
        return candidate
    }
}
