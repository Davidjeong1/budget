import SwiftUI
import SwiftData
import LedgerCore

struct HomeView: View {
    @Binding var month: MonthRange
    var onSeeAllTransactions: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var customCategories: [CustomCategory]

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    private var budgetTarget: Int? {
        budgets.first { $0.monthStart == month.start }.map(\.totalTarget).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBlock

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    summaryCard
                    weeklyTrend
                    recentTransactions
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    /// The design's wordmark block. The bell it draws beside it is not reproduced: there is no
    /// notification centre to open, and an affordance that does nothing is worse than none.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("다비드 가계부")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.accent)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.accent)
            }
            Text("MONEY LOG")
                .font(.appTitle)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader

            VStack(alignment: .leading, spacing: 4) {
                Text(CurrencyFormatter.string(from: headlineAmount))
                    .font(.cardAmount)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(headlineCaption)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textTertiary)
            }

            if let target = budgetTarget {
                ProgressBar(ratio: digest.budgetUsage(target: target), color: Palette.accent)

                // Not in the design, but the figure it adds is the one thing a monthly total cannot
                // say: whether this pace lands inside the budget.
                if let pace = digest.pace(target: target) {
                    Text(paceMessage(pace))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(paceColour(pace))
                }
            }

            splitBlocks
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    /// The design has no month control here, but every screen shares one and the ledger would
    /// otherwise be stuck on the current month, so the arrows sit either side of the label.
    private var cardHeader: some View {
        HStack(spacing: 8) {
            Button { month = month.previous } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.textTertiary)

            Text("\(month.monthLabel) \(budgetTarget == nil ? "지출" : "남은 예산")")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)

            Button { month = month.next } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.textTertiary)

            Spacer(minLength: 4)

            if let daysLeft = daysLeftInMonth {
                Text("D-\(daysLeft)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
        }
    }

    /// What the card leads with: the budget left, or the month's spending when no budget is set.
    private var headlineAmount: Int {
        guard let target = budgetTarget else { return digest.expenseTotal }
        return max(target - digest.expenseTotal, 0)
    }

    private var headlineCaption: String {
        guard let target = budgetTarget else { return "예산을 설정하면 남은 예산이 표시됩니다" }
        return "전체 예산 \(CurrencyFormatter.string(from: target))"
    }

    /// nil for any month but the one running — a day count into a finished month means nothing.
    private var daysLeftInMonth: Int? {
        let now = Date.now
        guard month.contains(now) else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: month.end
        ).day
        return days.map { max($0, 0) }
    }

    private var splitBlocks: some View {
        HStack(spacing: 12) {
            amountBlock(title: "총 수입", amount: digest.incomeTotal, colour: Palette.income)
            amountBlock(title: "총 지출", amount: digest.expenseTotal, colour: Palette.accent)
        }
    }

    private func amountBlock(title: String, amount: Int, colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
            Text(CurrencyFormatter.string(from: amount))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(colour)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardSurface(Palette.surfaceRaised, cornerRadius: 8)
    }

    private func paceMessage(_ pace: BudgetPace) -> String {
        switch pace {
        case .exceeded:
            "이번 달 예산을 이미 넘었습니다"
        case .runsOut(let day, _):
            "이 속도면 \(day)일에 예산을 다 씁니다"
        case .withinBudget(let projected):
            "이 속도면 월말에 \(CurrencyFormatter.string(from: projected)) 예상"
        }
    }

    private func paceColour(_ pace: BudgetPace) -> Color {
        switch pace {
        case .exceeded, .runsOut: Palette.expense
        case .withinBudget: Palette.textTertiary
        }
    }

    // MARK: - Trend

    private var weeklyTrend: some View {
        let weeks = digest.weeklyTotals()
        let maximum = max(weeks.map(\.total).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "주간 소비 추이")

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 8) {
                        // 60pt is the design's tallest bar; every bar scales against the month's own
                        // peak so an empty month still renders a flat baseline.
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 4
                        )
                        .fill(week.isCurrent ? Palette.accent : Palette.track)
                        .frame(
                            width: 28,
                            height: max(CGFloat(week.total) / CGFloat(maximum) * 60, 4)
                        )

                        Text(week.label)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 84, alignment: .bottom)
            .padding(16)
            .frame(maxWidth: .infinity)
            .cardSurface()
        }
    }

    // MARK: - Recent

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "최근 내역", trailing: "더보기", onTrailingTap: onSeeAllTransactions)

            if digest.recent.isEmpty {
                EmptyStateView(
                    title: "아직 내역이 없습니다",
                    message: "아래 추가 탭에서 첫 내역을 기록해 보세요."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(digest.recent) { transaction in
                        TransactionRow(
                            transaction: transaction,
                            category: catalog.category(forRaw: transaction.categoryRaw)
                        )
                    }
                }
            }
        }
    }
}
