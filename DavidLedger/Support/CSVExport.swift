import Foundation
import SwiftUI
import UniformTypeIdentifiers
import LedgerCore

/// A CSV of the ledger, for the 소비 데이터 내보내기 row. Wrapped in `Transferable` so it can be
/// handed straight to `ShareLink`.
struct LedgerCSV: Transferable {
    let text: String
    let filename: String

    init(transactions: [Transaction], now: Date = .now) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        var rows = ["날짜,구분,사용처,카테고리,금액,메모"]
        for transaction in transactions.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            rows.append(
                [
                    formatter.string(from: transaction.occurredAt),
                    transaction.isExpense ? "지출" : "수입",
                    Self.escape(transaction.merchant),
                    transaction.category.label,
                    String(transaction.amount),
                    Self.escape(transaction.memo),
                ].joined(separator: ",")
            )
        }

        // A BOM so Excel on Windows opens the Korean text as UTF-8 instead of mojibake.
        self.text = "\u{FEFF}" + rows.joined(separator: "\n")

        let stamp = now.formatted(.iso8601.year().month().day())
        self.filename = "davidledger-\(stamp).csv"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            Data(csv.text.utf8)
        }
        .suggestedFileName { $0.filename }
    }
}
