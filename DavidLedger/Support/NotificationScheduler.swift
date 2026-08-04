import Foundation
import UserNotifications

/// Local notifications for the two alert toggles. Everything here is best-effort: if the user
/// declines the permission prompt the toggles simply do nothing, which is why each entry point
/// requests authorisation rather than assuming it.
enum NotificationScheduler {

    private static let dailyReminderID = "daily-reminder"
    private static let budgetAlertPrefix = "budget-alert-"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// A 21:00 nudge to record the day's spending.
    static func setDailyReminder(enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
        guard enabled, await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "오늘 소비 기록하기"
        content.body = "오늘 쓴 내역을 가계부에 남겨 보세요."
        content.sound = .default

        var components = DateComponents()
        components.hour = 21
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    private static let alertedMonthsKey = "notifications.alertedBudgetMonths"

    /// Fixed-width UTC stamps, which is what lets the set be sorted as plain strings below. The
    /// value is only ever compared against itself, so the zone it renders in does not matter as
    /// long as it is the same one every time — a floating `.current` would produce two different
    /// keys for one month if the user crossed a time zone.
    private static let monthKeyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// How many months of history the set keeps. It is only ever consulted for the month being
    /// saved into, so older entries answer nothing — and without a bound the list grows for the
    /// life of the install.
    private static let alertedMonthsKept = 24

    /// Fires once when a month's spending first crosses 90% of its budget.
    ///
    /// The set of already-alerted months is kept in UserDefaults rather than inferred from
    /// `deliveredNotifications()`, which empties as soon as the user clears Notification Center
    /// and would let the alert fire again on every subsequent save.
    ///
    /// In the group suite with every other preference, not `.standard`. Nothing outside the app
    /// writes this today, but a ledger split across two suites is a trap for whoever adds the next
    /// extension — and the group is where a reader would look for it.
    static func notifyBudgetThresholdIfNeeded(
        monthStart: Date,
        percent: Int,
        enabled: Bool,
        defaults: UserDefaults = AppGroup.defaults
    ) async {
        guard enabled, percent >= 90 else { return }

        let monthKey = monthKeyFormatter.string(from: monthStart)
        var alerted = Set(defaults.stringArray(forKey: alertedMonthsKey) ?? [])
        guard !alerted.contains(monthKey), await requestAuthorization() else { return }
        alerted.insert(monthKey)
        defaults.set(Array(alerted.sorted().suffix(alertedMonthsKept)), forKey: alertedMonthsKey)

        let center = UNUserNotificationCenter.current()
        let identifier = budgetAlertPrefix + monthKey

        let content = UNMutableNotificationContent()
        content.title = "예산 \(percent)% 사용"
        content.body = "이번 달 예산의 \(percent)%를 썼습니다."
        content.sound = .default

        try? await center.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        )
    }
}
