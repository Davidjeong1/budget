import Foundation
import SwiftData
import LedgerCore

enum LedgerStore {
    /// One container per process. `static let` is lazy and runs its initialiser exactly once.
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Transaction.self, Budget.self)
        } catch {
            fatalError("가계부 저장소를 열지 못했습니다: \(error)")
        }
    }()

    /// Fetches the budget for `month`, creating nothing — the budget screen decides whether to
    /// insert one, so a read never has a write side effect.
    static func budget(for month: MonthRange, in context: ModelContext) -> Budget? {
        let start = month.start
        var descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.monthStart == start })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

/// A calendar month. Scopes every screen's totals and drives the month stepper.
struct MonthRange: Equatable {
    let start: Date
    let end: Date
    private let calendar: Calendar

    init(containing date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        let interval = calendar.dateInterval(of: .month, for: date)
        self.start = interval?.start ?? date
        self.end = interval?.end ?? date
    }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    /// "10월" — the dashboard card and the statistics header both label the month this way.
    var monthLabel: String { start.monthLabel }

    var title: String {
        start.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).year().month())
    }

    var previous: MonthRange {
        MonthRange(containing: calendar.date(byAdding: .month, value: -1, to: start) ?? start, calendar: calendar)
    }

    var next: MonthRange {
        MonthRange(containing: calendar.date(byAdding: .month, value: 1, to: start) ?? start, calendar: calendar)
    }

    /// Week buckets for the dashboard's 주간 지출 추이 chart, oldest first. The final bucket is the
    /// one containing today when the month being shown is the current month.
    func weekBuckets(now: Date = .now) -> [(label: String, range: Range<Date>)] {
        var buckets: [(String, Range<Date>)] = []
        var cursor = start
        var index = 1
        while cursor < end {
            let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? end
            let bucketEnd = min(next, end)
            let isCurrent = now >= cursor && now < bucketEnd
            buckets.append((isCurrent ? "\(index)주(이번주)" : "\(index)주", cursor..<bucketEnd))
            cursor = bucketEnd
            index += 1
        }
        return buckets
    }

    static func == (lhs: MonthRange, rhs: MonthRange) -> Bool { lhs.start == rhs.start }
}
