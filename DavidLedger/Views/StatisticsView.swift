import SwiftUI
import SwiftData
import LedgerCore

struct StatisticsView: View {
    @Binding var month: MonthRange

    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var customCategories: [CustomCategory]

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    /// Spend per category with the stored keys resolved, largest first. The rank is what colours
    /// each row and slice in this design, so the order is part of the output.
    private var breakdown: [(category: LedgerCategory, total: Int, share: Double)] {
        let totals = digest.categoryTotals
        let sum = totals.reduce(0) { $0 + $1.total }
        guard sum > 0 else { return [] }
        return totals.map {
            (
                category: catalog.category(forRaw: $0.raw),
                total: $0.total,
                share: Double($0.total) / Double(sum)
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if breakdown.isEmpty {
                        EmptyStateView(
                            title: "분석할 지출이 없습니다",
                            message: "이 달에 기록된 지출이 아직 없습니다."
                        )
                        .padding(.top, 40)
                    } else {
                        donut
                        breakdownSection
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var headerBar: some View {
        ScreenTitleBar(title: "지출 분석", month: $month)
    }

    private var donut: some View {
        ZStack {
            DonutChart(
                slices: breakdown.enumerated().map { index, entry in
                    (share: entry.share, color: Palette.accentShade(index))
                }
            )
            .frame(width: 150, height: 150)

            VStack(spacing: 4) {
                Text("총 지출")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Text(CurrencyFormatter.string(from: digest.expenseTotal))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: 180, height: 180)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 24)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("카테고리 비율")
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)

            VStack(spacing: 12) {
                ForEach(Array(breakdown.enumerated()), id: \.element.category) { index, entry in
                    breakdownRow(entry, rank: index)
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 12)
    }

    private func breakdownRow(
        _ entry: (category: LedgerCategory, total: Int, share: Double),
        rank: Int
    ) -> some View {
        let shade = Palette.accentShade(rank)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: entry.category.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(shade)
                    .frame(width: 16)

                Text(entry.category.label)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                Text("\(Int((entry.share * 100).rounded()))%")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)

                Spacer(minLength: 8)

                Text(CurrencyFormatter.string(from: entry.total))
                    .font(.rowAmount)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            }

            ProgressBar(ratio: entry.share, color: shade)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// A donut drawn from the slice shares. Hand-drawn rather than using Swift Charts so the ring
/// thickness and the gap-free layout match the design exactly.
private struct DonutChart: View {
    let slices: [(share: Double, color: Color)]
    var thickness: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            var start = Angle.degrees(-90)

            for slice in slices {
                let sweep = Angle.degrees(slice.share * 360)
                let end = start + sweep

                var path = Path()
                path.addArc(
                    center: centre,
                    radius: radius - thickness / 2,
                    startAngle: start,
                    endAngle: end,
                    clockwise: false
                )
                context.stroke(
                    path,
                    with: .color(slice.color),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .butt)
                )
                start = end
            }
        }
        .accessibilityHidden(true)
    }
}
