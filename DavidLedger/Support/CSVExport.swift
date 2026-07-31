import Foundation
import SwiftUI
import UIKit
import CoreTransferable
import UniformTypeIdentifiers
import LedgerCore

/// A CSV of the ledger, for the 소비 데이터 내보내기 row. Wrapped in `Transferable` so it can be
/// handed straight to `ShareLink`.
struct LedgerCSV: Transferable, Identifiable {
    let text: String
    let filename: String

    var id: String { filename }

    /// Writes the CSV out so the share sheet offers file destinations (Files, Mail attachment)
    /// rather than pasting the whole ledger inline as text.
    func writeToTemporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    init(transactions: [Transaction], now: Date = .now) {
        let formatter = ISO8601DateFormatter()
        // Defaults to UTC, which would export a 08:00 KST payment as the previous calendar day and
        // quietly break any month-based analysis done on the file.
        formatter.timeZone = .current
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

/// The system share sheet. Used instead of `ShareLink` so the CSV is only built when the user
/// actually taps export, rather than on every settings-screen body evaluation.
struct ShareSheet: UIViewControllerRepresentable {
    let csv: LedgerCSV

    // The `context` label is required by UIViewControllerRepresentable, so the parameters are
    // named `_` rather than dropped — renaming the label would break the conformance.
    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let item: Any = (try? csv.writeToTemporaryFile()) ?? csv.text
        return UIActivityViewController(activityItems: [item], applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {
        // Intentionally empty. The share sheet is configured once in makeUIViewController and has
        // no state to refresh: the CSV is snapshotted when the user taps export, and a new sheet
        // is built from scratch on each presentation.
    }
}
