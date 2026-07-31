import Foundation
import SwiftData
import LedgerCore

enum LedgerStore {
    /// One container per process. `static let` is lazy and runs its initialiser exactly once.
    static let shared: ModelContainer = makeContainer()

    /// True when the on-disk store could not be opened and the app is running against memory, so
    /// the UI can warn that nothing is being saved.
    private(set) static var isEphemeral = false

    private static func makeContainer() -> ModelContainer {
        if let container = try? ModelContainer(for: Transaction.self, Budget.self) {
            return container
        }
        // A corrupt store should not be a launch crash: fall back to memory so the ledger still
        // opens and the user can see what state it is in.
        isEphemeral = true
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let fallback = try? ModelContainer(
            for: Transaction.self, Budget.self,
            configurations: configuration
        ) else {
            fatalError("가계부 저장소를 열지 못했습니다.")
        }
        return fallback
    }

    /// Fetches the budget for `month`. Goes to the store rather than a `@Query` snapshot, so a
    /// budget inserted earlier in the same update cycle is still found and not duplicated.
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

    /// Week buckets for the dashboard's 주간 지출 추이 chart, oldest first. Buckets are anchored to
    /// the 1st of the month, so "이번주" means the seven-day block containing today rather than a
    /// Mon–Sun calendar week. `isCurrent` is returned rather than encoded in the label, so a copy
    /// change cannot silently unflag every bar.
    func weekBuckets(now: Date = .now) -> [(label: String, range: Range<Date>, isCurrent: Bool)] {
        var buckets: [(String, Range<Date>, Bool)] = []
        var cursor = start
        var index = 1
        while cursor < end {
            let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? end
            let bucketEnd = min(next, end)
            let isCurrent = now >= cursor && now < bucketEnd
            buckets.append((isCurrent ? "\(index)주(이번주)" : "\(index)주", cursor..<bucketEnd, isCurrent))
            cursor = bucketEnd
            index += 1
        }
        return buckets
    }

    static func == (lhs: MonthRange, rhs: MonthRange) -> Bool { lhs.start == rhs.start }
}
