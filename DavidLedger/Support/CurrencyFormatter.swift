import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    private static func grouped(_ amount: Int) -> String {
        formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    /// "₩ 1,284,500" — the design keeps a space after the symbol.
    static func string(from amount: Int) -> String {
        "₩ \(grouped(abs(amount)))"
    }

    /// "-₩ 24,500" / "+₩ 2,500,000", with the sign outside the symbol as the design shows it.
    static func signedString(from amount: Int) -> String {
        let sign = amount < 0 ? "-" : (amount > 0 ? "+" : "")
        return "\(sign)₩ \(grouped(abs(amount)))"
    }

    /// "₩ 1,284.5k" — the compact form used for the donut centre on the statistics screen.
    static func compactString(from amount: Int) -> String {
        let magnitude = abs(amount)
        guard magnitude >= 1_000 else { return string(from: amount) }
        let thousands = Double(magnitude) / 1_000
        let rendered = thousands < 100
            ? String(format: "%.1f", thousands)
            : String(format: "%.0f", thousands)
        return "₩ \(rendered)k"
    }
}

extension Date {
    /// "10월 24일 오늘" — the transaction list's day header, which names today and yesterday.
    func dayHeader(calendar: Calendar = .current, now: Date = .now) -> String {
        let base = formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day())
        if calendar.isDateInToday(self) { return "\(base) 오늘" }
        if calendar.isDateInYesterday(self) { return "\(base) 어제" }
        return base
    }

    /// "오늘 14:32" on the dashboard, where the row has no day header to sit under.
    func relativeDayAndTime(calendar: Calendar = .current) -> String {
        let time = formatted(
            .dateTime.locale(Locale(identifier: "ko_KR")).hour(.twoDigits(amPM: .omitted)).minute()
        )
        if calendar.isDateInToday(self) { return "오늘 \(time)" }
        if calendar.isDateInYesterday(self) { return "어제 \(time)" }
        let day = formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day())
        return "\(day) \(time)"
    }

    var timeLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).hour(.twoDigits(amPM: .omitted)).minute())
    }

    /// "2024년 10월 24일" — the add screen's date row.
    var longDateLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).year().month().day())
    }

    /// "10월" — used in the dashboard card's "10월 소비 현황".
    var monthLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month())
    }
}
