import Foundation

/// What a Korean card-approval text message says, as far as it can be read.
///
/// iOS cannot read these messages by itself — the app only ever sees one the user hands over by
/// pasting or sharing it. See the README for why the automatic route does not exist.
public struct PaymentMessage: Equatable, Sendable {
    public let amount: Int
    /// nil when no part of the message looks like a merchant. The amount alone is still worth
    /// filling in, so this does not fail the whole parse.
    public let merchant: String?
    /// Approvals and cancellations read almost identically, and getting the direction wrong writes
    /// a bad row into the ledger. The caller is told which one this is rather than having the sign
    /// flipped for it.
    public let isCancellation: Bool
    /// The year is not in these messages, so only month and day are reported.
    public let month: Int?
    public let day: Int?
    public let hour: Int?
    public let minute: Int?

    public init(
        amount: Int,
        merchant: String?,
        isCancellation: Bool,
        month: Int? = nil,
        day: Int? = nil,
        hour: Int? = nil,
        minute: Int? = nil
    ) {
        self.amount = amount
        self.merchant = merchant
        self.isCancellation = isCancellation
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }
}

public extension PaymentMessage {
    /// The moment this message describes, as a date.
    ///
    /// These messages carry no year, so the most recent matching date is assumed: a 12/31 message
    /// read on 1 January belongs to last year, not eleven months into the future. Midday stands in
    /// for a missing time, which keeps the row inside the right calendar day in any time zone.
    func occurredAt(now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let month, let day else { return nil }

        var components = calendar.dateComponents([.year], from: now)
        components.month = month
        components.day = day
        components.hour = hour ?? 12
        components.minute = minute ?? 0

        guard let candidate = calendar.date(from: components) else { return nil }
        guard candidate > now else { return candidate }

        components.year = (components.year ?? calendar.component(.year, from: now)) - 1
        return calendar.date(from: components)
    }
}

/// Reads a pasted card-approval message. Deliberately forgiving: the carriers all lay these out
/// differently and none of the formats are specified anywhere, so every field beyond the amount is
/// best-effort and the user confirms the result before it is saved.
public enum PaymentMessageParser {

    /// Amounts introduced by one of these are totals or limits, not what was just charged.
    /// Not "총": it opens too many ordinary merchant names (총각네…) to be safe this close to a number.
    private static let runningTotalMarkers = ["누적", "잔액", "한도", "합계", "적립", "포인트"]

    /// Words that mark a line as belonging to the carrier's boilerplate rather than the merchant.
    private static let boilerplate = [
        "발신", "카드", "승인", "취소", "체크", "신용", "일시불", "할부",
        "누적", "잔액", "한도", "합계", "결제", "출금", "입금", "은행", "이용",
    ]

    /// - Returns: nil when the text carries no amount, which is the one field the ledger cannot do
    ///   without.
    public static func parse(_ text: String) -> PaymentMessage? {
        guard let amount = chargedAmount(in: text) else { return nil }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let stamp = timestamp(in: text)

        return PaymentMessage(
            amount: amount,
            merchant: merchant(in: lines),
            isCancellation: text.contains("취소"),
            month: stamp.month,
            day: stamp.day,
            hour: stamp.hour,
            minute: stamp.minute
        )
    }

    // MARK: - Amount

    /// The first "12,000원" in the message that is not a running total. First rather than largest:
    /// the charge leads the message and the accumulated total trails it, and the total is the
    /// larger of the two.
    private static func chargedAmount(in text: String) -> Int? {
        amount(in: text, skippingRunningTotals: true)
    }

    private static func amount(in text: String, skippingRunningTotals: Bool) -> Int? {
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }

            var end = index
            while end < characters.count, characters[end].isNumber || characters[end] == "," {
                end += 1
            }

            if end < characters.count, characters[end] == "원",
               !(skippingRunningTotals && isRunningTotal(characters, endingBefore: index)),
               let value = Int(String(characters[index..<end].filter(\.isNumber))),
               value > 0 {
                return value
            }

            index = max(end, index + 1)
        }

        return nil
    }

    /// Looks back a few characters for a marker, which is where the carriers put them: "누적 350,000원".
    private static func isRunningTotal(_ characters: [Character], endingBefore start: Int) -> Bool {
        let window = String(characters[max(0, start - 8)..<start])
        return runningTotalMarkers.contains { window.contains($0) }
    }

    // MARK: - Timestamp

    private static func timestamp(in text: String) -> (month: Int?, day: Int?, hour: Int?, minute: Int?) {
        let characters = Array(text)
        var month: Int?
        var day: Int?
        var hour: Int?
        var minute: Int?
        var index = 0

        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }

            let (leading, afterLeading) = number(in: characters, from: index)
            guard afterLeading < characters.count else { break }

            let separator = characters[afterLeading]
            let (trailing, afterTrailing) = number(in: characters, from: afterLeading + 1)

            if let leading, let trailing, afterTrailing > afterLeading + 1 {
                if (separator == "/" || separator == ".") && month == nil,
                   (1...12).contains(leading), (1...31).contains(trailing) {
                    month = leading
                    day = trailing
                } else if separator == ":" && hour == nil,
                          (0...23).contains(leading), (0...59).contains(trailing) {
                    hour = leading
                    minute = trailing
                }
            }

            index = afterLeading
        }

        return (month, day, hour, minute)
    }

    /// Reads a run of at most two digits, so a card number or an amount cannot be mistaken for a
    /// month. Returns the value and the index just past it.
    private static func number(in characters: [Character], from start: Int) -> (Int?, Int) {
        var end = start
        while end < characters.count, characters[end].isNumber { end += 1 }
        guard end > start, end - start <= 2 else { return (nil, end) }
        return (Int(String(characters[start..<end])), end)
    }

    // MARK: - Merchant

    private static func merchant(in lines: [String]) -> String? {
        // The carriers that break the message across lines put the merchant on a line of its own,
        // last, after the amount and the timestamp.
        if let onItsOwnLine = lines.last(where: isMerchantLine) {
            return onItsOwnLine
        }
        // The ones that do not put it at the end of the single line, behind the timestamp.
        return lines.compactMap(trailingMerchant).last
    }

    private static func isMerchantLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        guard !boilerplate.contains(where: line.contains) else { return false }
        // An amount line has to be ruled out by looking for the amount, not by looking for digits:
        // 원 is a letter, so "12,000원" reads as a name, and real merchants (GS25, 이마트24) carry
        // digits of their own.
        guard amount(in: line, skippingRunningTotals: false) == nil else { return false }
        // What is left of a timestamp line is digits and punctuation, with no name in it.
        return line.contains { $0.isLetter }
    }

    private static func trailingMerchant(_ line: String) -> String? {
        let tokens = line.split(separator: " ").map(String.init)
        guard let lastTemporal = tokens.lastIndex(where: looksTemporal) else { return nil }
        let rest = tokens[(lastTemporal + 1)...]
        guard !rest.isEmpty else { return nil }
        return rest.joined(separator: " ")
    }

    /// "07/31" or "14:23" — digits around a date or time separator, and nothing else.
    private static func looksTemporal(_ token: String) -> Bool {
        guard token.contains(":") || token.contains("/") || token.contains(".") else { return false }
        return token.allSatisfy { $0.isNumber || $0 == ":" || $0 == "/" || $0 == "." }
    }
}
