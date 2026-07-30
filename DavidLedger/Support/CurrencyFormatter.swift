import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    static func string(from amount: Int) -> String {
        let number = formatter.string(from: NSNumber(value: amount)) ?? String(amount)
        return "\(number)원"
    }

    /// Renders a signed amount the way a ledger reads it: money out is negative, money back in
    /// (income, or a cancelled approval) is positive.
    static func signedString(from amount: Int) -> String {
        amount >= 0 ? "+\(string(from: amount))" : string(from: amount)
    }
}

extension Date {
    var dayLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day().weekday())
    }

    var timeLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).hour().minute())
    }
}
