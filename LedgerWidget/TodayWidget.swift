import WidgetKit
import SwiftUI
import SwiftData
import LedgerCore

/// The home screen widget: what was spent today, and how far into the month's budget that is.
///
/// A ledger's value is being looked at before the money is spent, not after it is recorded, which
/// is the one thing an app icon cannot do.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("오늘 쓴 돈")
        .description("오늘 지출과 이번 달 예산 사용률을 보여줍니다.")
        .supportedFamilies([.systemSmall])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let todaySpend: Int
    let monthSpend: Int
    let budgetTarget: Int

    var hasBudget: Bool { budgetTarget > 0 }

    /// Clamped for the ring, which cannot draw past a full turn. The percentage below is not
    /// clamped — an overspent month should read 130%, not 100%.
    var usage: Double {
        guard hasBudget else { return 0 }
        return min(max(Double(monthSpend) / Double(budgetTarget), 0), 1)
    }

    var percent: Int {
        guard hasBudget else { return 0 }
        return Int((Double(monthSpend) / Double(budgetTarget) * 100).rounded())
    }

    var remaining: Int { max(budgetTarget - monthSpend, 0) }

    /// Shown in the widget gallery and while the real figures are being read, so it carries
    /// plausible numbers rather than zeroes.
    static let placeholder = TodayEntry(
        date: .now,
        todaySpend: 30_100,
        monthSpend: 1_284_500,
        budgetTarget: 2_000_000
    )

    /// Read straight from the shared store. The widget runs as its own process, so it opens the
    /// app group container rather than talking to the app.
    static func current(now: Date = .now) -> TodayEntry {
        let context = ModelContext(LedgerStore.shared)
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []

        let month = MonthRange(containing: now)
        let calendar = Calendar.current
        let todaySpend = transactions
            .filter { $0.isExpense && calendar.isDate($0.occurredAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.amount }

        return TodayEntry(
            date: now,
            todaySpend: todaySpend,
            // Through MonthlyDigest so the widget cannot disagree with the home screen about what
            // the month's spending was.
            monthSpend: MonthlyDigest(month: month, allTransactions: transactions).expenseTotal,
            budgetTarget: LedgerStore.budget(for: month, in: context)?.totalTarget ?? 0
        )
    }
}

struct TodayProvider: TimelineProvider {
    // The `in` labels are required by TimelineProvider; only getSnapshot reads its context.
    func placeholder(in _: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // Refreshed at midnight because today's figure resets then. Every other change comes from
        // the app or the share extension saving a row, which reloads the timeline directly.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(24 * 60 * 60))
        completion(Timeline(entries: [.current()], policy: .after(midnight)))
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 8)
            summary
            Spacer(minLength: 8)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Palette.accent)
                .frame(width: 8, height: 8)

            // The design mocks a different product name; this is the app's own.
            Text("다비드 가계부")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Text("오늘")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("오늘 쓴 돈")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textSecondary)

            Text(CurrencyFormatter.string(from: entry.todaySpend))
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                // A seven-figure day would otherwise push the amount out of a small widget.
                .minimumScaleFactor(0.6)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if entry.hasBudget {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("예산 대비 \(entry.percent)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    Text("남은 예산 \(CurrencyFormatter.string(from: entry.remaining))")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                ring
            }
        } else {
            Text("예산을 설정하면 사용률이 표시됩니다")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(2)
        }
    }

    /// Drawn rather than loaded from the exported ring images: the sweep is the live figure, so a
    /// static asset could only ever show the percentage the mock happened to use. Matches how the
    /// app draws its own donut and progress bars.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Palette.border, lineWidth: 6)

            Circle()
                .trim(from: 0, to: entry.usage)
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(entry.percent)%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.accent)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 46, height: 46)
    }
}

#Preview(as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry.placeholder
    TodayEntry(date: .now, todaySpend: 0, monthSpend: 0, budgetTarget: 0)
}
