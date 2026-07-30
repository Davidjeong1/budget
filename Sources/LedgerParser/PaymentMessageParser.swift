import Foundation

/// Parses Korean bank / card-company / simple-pay approval texts.
///
/// This is intentionally a set of tolerant heuristics rather than a strict grammar: real messages
/// vary card company to card company, so every extractor degrades gracefully (returns nil) instead
/// of throwing, and `parse` only requires an amount to produce a result.
public enum PaymentMessageParser {

    private static let amountPattern = #"(\d{1,3}(?:,\d{3})+|\d+)\s*원"#
    private static let dateTimePattern = #"(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})"#
    private static let cardLast4Pattern = #"\((\d{4})\)"#
    private static let installmentPattern = #"(\d{1,2})\s*개월(?:\s*할부)?"#
    private static let cancellationPattern = #"승인\s*취소|결제\s*취소|취소\s*완료"#
    private static let bracketPattern = #"\[[^\]]*\]"#

    private static let amountRegex = regex(amountPattern)
    private static let dateTimeRegex = regex(dateTimePattern)
    private static let cardLast4Regex = regex(cardLast4Pattern)
    private static let installmentRegex = regex(installmentPattern)
    private static let cancellationRegex = regex(cancellationPattern)
    private static let bracketRegex = regex(bracketPattern)

    /// Amounts introduced by one of these are running totals or limits, not the payment.
    private static let amountContextExclude = ["누적", "잔액", "한도", "포인트", "적립", "캐시백"]

    private static let approvalKeywords = ["승인", "결제", "체크승인"]

    private static let knownIssuers: [String] = [
        "KB국민카드", "국민카드", "신한카드", "삼성카드", "우리카드", "하나카드",
        "롯데카드", "현대카드", "NH농협카드", "농협카드", "비씨카드", "BC카드",
        "씨티카드", "카카오페이", "네이버페이", "토스", "페이코",
    ]
    // Longest first so "KB국민카드" wins over "국민카드". The name breaks ties, because Swift's sort
    // is not guaranteed stable and several issuers are the same length.
    .sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }

    /// Stripped as substrings, longest first, because they are routinely written with no space
    /// between them and the issuer or the merchant.
    private static let gluedSuffixes = ["승인취소", "결제취소", "결제완료", "체크승인", "승인", "결제", "취소", "완료"]

    private static let merchantStopTokens: Set<String> = [
        "카드", "앱카드", "승인", "정상승인", "체크승인", "정상", "체크카드", "해외", "국내", "일시불",
        "완료", "결제", "결제완료", "취소", "포인트", "적립", "누적", "잔액", "한도",
        "web발신", "웹발신", "총누적",
    ]

    /// Cheap pre-filter so callers can skip obviously irrelevant text before doing real work.
    public static func looksLikePaymentMessage(_ text: String) -> Bool {
        let hasApprovalKeyword = approvalKeywords.contains { text.contains($0) }
        let hasWonAmount = firstMatch(amountRegex, in: text) != nil
        return hasApprovalKeyword && hasWonAmount
    }

    public static func parse(
        _ text: String,
        source: PaymentSource = .shortcutAutomation
    ) -> ParsedPayment? {
        guard looksLikePaymentMessage(text) else { return nil }
        guard let amountMatch = findAmountMatch(in: text) else { return nil }
        guard let amount = Int(group(1, of: amountMatch, in: text)?
            .replacingOccurrences(of: ",", with: "") ?? "") else { return nil }

        let dateTimeMatch = firstMatch(dateTimeRegex, in: text)

        var approvedAt: PartialDateTime?
        if let dateTimeMatch {
            approvedAt = PartialDateTime(
                month: group(1, of: dateTimeMatch, in: text).flatMap(Int.init),
                day: group(2, of: dateTimeMatch, in: text).flatMap(Int.init),
                hour: group(3, of: dateTimeMatch, in: text).flatMap(Int.init),
                minute: group(4, of: dateTimeMatch, in: text).flatMap(Int.init)
            )
        }

        var installmentMonths: Int?
        if !text.contains("일시불"), let match = firstMatch(installmentRegex, in: text) {
            installmentMonths = group(1, of: match, in: text).flatMap(Int.init)
        }

        let cardLast4 = firstMatch(cardLast4Regex, in: text)
            .flatMap { group(1, of: $0, in: text) }

        return ParsedPayment(
            amount: amount,
            merchant: extractMerchant(from: text, dateTimeMatch: dateTimeMatch, amountMatch: amountMatch),
            issuer: knownIssuers.first { text.contains($0) },
            cardLast4: cardLast4,
            approvedAt: approvedAt,
            installmentMonths: installmentMonths,
            isCancellation: firstMatch(cancellationRegex, in: text) != nil,
            source: source,
            rawText: text
        )
    }

    // MARK: - Amount

    private static func findAmountMatch(in text: String) -> NSTextCheckingResult? {
        let ns = text as NSString
        let matches = amountRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            let contextStart = max(0, match.range.location - 10)
            let context = ns.substring(with: NSRange(
                location: contextStart,
                length: match.range.location - contextStart
            ))
            if amountContextExclude.contains(where: { context.contains($0) }) { continue }
            return match
        }
        return nil
    }

    // MARK: - Merchant

    private static func extractMerchant(
        from text: String,
        dateTimeMatch: NSTextCheckingResult?,
        amountMatch: NSTextCheckingResult
    ) -> String? {
        let ns = text as NSString

        // Most card messages put the merchant right after the date/time stamp, on the same line.
        if let dateTimeMatch {
            let tailStart = dateTimeMatch.range.location + dateTimeMatch.range.length
            if tailStart < ns.length {
                let tail = ns.substring(from: tailStart)
                let segment = tail.components(separatedBy: "\n").first ?? tail
                if let candidate = cleanMerchantCandidate(segment) { return candidate }
            }
        }

        // Simple-pay formats often put the merchant before the amount on the same line.
        let lineStart = lineStartIndex(in: ns, before: amountMatch.range.location)
        let before = ns.substring(with: NSRange(
            location: lineStart,
            length: amountMatch.range.location - lineStart
        ))
        if let candidate = cleanMerchantCandidate(before) { return candidate }

        // Fall back to scanning every line, last first, for a plausible candidate.
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for line in lines.reversed() {
            if let candidate = cleanMerchantCandidate(line), (2...40).contains(candidate.count) {
                return candidate
            }
        }
        return nil
    }

    /// Stays in UTF-16 offsets throughout, because mixing them with `String.Index` distances
    /// silently misaligns as soon as the text contains a non-BMP character such as an emoji.
    private static func lineStartIndex(in ns: NSString, before location: Int) -> Int {
        let newline = ns.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: location))
        guard newline.location != NSNotFound else { return 0 }
        return newline.location + newline.length
    }

    private static func cleanMerchantCandidate(_ raw: String) -> String? {
        var s = raw
        // Reuses the cached regexes: this runs once per candidate line, so recompiling five
        // patterns each time would be the most expensive part of parsing a message.
        for expression in [bracketRegex, cardLast4Regex, dateTimeRegex, amountRegex, installmentRegex] {
            s = expression.stringByReplacingMatches(
                in: s,
                range: NSRange(location: 0, length: (s as NSString).length),
                withTemplate: " "
            )
        }

        // Card companies often glue the issuer to the keyword ("우리카드승인"), which would survive
        // whole-token filtering and end up in the merchant name.
        for issuer in knownIssuers {
            s = s.replacingOccurrences(of: issuer, with: " ", options: .caseInsensitive)
        }
        for keyword in gluedSuffixes {
            s = s.replacingOccurrences(of: keyword, with: " ")
        }

        let tokens = s
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { token in !knownIssuers.contains { $0.caseInsensitiveCompare(token) == .orderedSame } }
            .filter { token in !merchantStopTokens.contains { $0.caseInsensitiveCompare(token) == .orderedSame } }
            .filter { !$0.hasSuffix("님") }
            .filter { !$0.allSatisfy(\.isNumber) }

        let result = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }

    // MARK: - Regex helpers

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Every pattern here is a compile-time literal, so a failure is a programming error.
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            preconditionFailure("Invalid regular expression: \(pattern)")
        }
        return regex
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: range)
    }
}
