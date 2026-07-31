import SwiftUI
import SwiftData
import LedgerCore

struct HomeView: View {
    @Binding var month: MonthRange
    var onSeeAllTransactions: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    private var budgetTarget: Int? {
        budgets.first { $0.monthStart == month.start }.map(\.totalTarget)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The design has a bell here, but there is no notification centre to open — an
            // affordance that does nothing is worse than none.
            ScreenHeader(title: "다비드 가계부")

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

    private var summaryCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        month = month.previous
                    } label: {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.textTertiary)

                    Text("\(month.monthLabel) 소비 현황")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)

                    Button {
                        month = month.next
                    } label: {
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.textTertiary)

                    Spacer()

                    if let budgetTarget {
                        Text("예산 대비 \(digest.budgetPercent(target: budgetTarget))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(CurrencyFormatter.string(from: digest.expenseTotal))
                        .font(.cardAmount)
                        .foregroundStyle(Palette.textPrimary)
                    if let budgetTarget {
                        Text("남은 예산 \(CurrencyFormatter.string(from: max(budgetTarget - digest.expenseTotal, 0)))")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textTertiary)
                    } else {
                        Text("예산을 설정하면 남은 금액이 표시됩니다")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }

                Rectangle().fill(Palette.border).frame(height: 1)

                HStack(spacing: 16) {
                    amountColumn(title: "수입", amount: digest.incomeTotal, color: Palette.income)
                    amountColumn(title: "지출", amount: digest.expenseTotal, color: Palette.expense)
                }
            }
        }
    }

    private func amountColumn(title: String, amount: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.captionSmall)
                .foregroundStyle(Palette.textSecondary)
            Text(CurrencyFormatter.string(from: amount))
                .font(.bodyValue)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weeklyTrend: some View {
        let weeks = digest.weeklyTotals()
        let maximum = max(weeks.map(\.total).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "주간 지출 추이")

            HStack(alignment: .bottom) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 8) {
                        // 76pt is the tallest bar in the design; every bar scales against the
                        // month's own peak so an empty month still renders a flat baseline.
                        RoundedRectangle(cornerRadius: 4)
                            .fill(week.isCurrent ? Palette.accent : Palette.border)
                            .frame(width: 20, height: max(CGFloat(week.total) / CGFloat(maximum) * 76, 4))
                        Text(week.label)
                            .font(.system(size: 11, weight: week.isCurrent ? .semibold : .regular))
                            .foregroundStyle(week.isCurrent ? Palette.accent : Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)
            .padding(.bottom, 8)
        }
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "최근 내역", trailing: "더보기", onTrailingTap: onSeeAllTransactions)

            if digest.recent.isEmpty {
                EmptyStateView(
                    title: "아직 내역이 없습니다",
                    message: "아래 추가 탭에서 첫 내역을 기록해 보세요."
                )
            } else {
                VStack(spacing: Metrics.rowSpacing) {
                    ForEach(digest.recent) { transaction in
                        CompactTransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }
}
