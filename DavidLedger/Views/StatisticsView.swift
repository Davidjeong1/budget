import SwiftUI
import SwiftData
import LedgerCore

struct StatisticsView: View {
    @Binding var month: MonthRange

    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    /// The donut shows the top four categories and rolls the rest into 기타, matching the design's
    /// four-slice legend rather than drawing a sliver per category.
    private var slices: [(category: Category, total: Int, share: Double)] {
        let totals = digest.categoryTotals
        guard !totals.isEmpty else { return [] }
        let sum = totals.reduce(0) { $0 + $1.total }
        guard sum > 0 else { return [] }

        let leading = totals.prefix(4)
        let remainder = totals.dropFirst(4).reduce(0) { $0 + $1.total }
        var entries = leading.map { (category: $0.category, total: $0.total) }
        if remainder > 0 {
            if let index = entries.firstIndex(where: { $0.category == .etc }) {
                entries[index].total += remainder
            } else {
                entries.append((category: .etc, total: remainder))
            }
        }
        return entries.map { ($0.category, $0.total, Double($0.total) / Double(sum)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "지출 분석")

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    monthStepper

                    if slices.isEmpty {
                        EmptyStateView(
                            title: "분석할 지출이 없습니다",
                            message: "이 달에 기록된 지출이 아직 없습니다."
                        )
                    } else {
                        donutSection
                        topCategories
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var monthStepper: some View {
        HStack {
            Button { month = month.previous } label: {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(month.title).font(.system(size: 14, weight: .semibold))
            Spacer()
            Button { month = month.next } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Palette.textSecondary)
    }

    private var donutSection: some View {
        VStack(spacing: 24) {
            ZStack {
                DonutChart(slices: slices.map { (share: $0.share, color: $0.category.color) })
                    .frame(width: 180, height: 180)

                VStack(spacing: 2) {
                    Text("총 지출")
                        .font(.captionSmall)
                        .foregroundStyle(Palette.textSecondary)
                    Text(CurrencyFormatter.compactString(from: digest.expenseTotal))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                ForEach(slices, id: \.category) { slice in
                    HStack(spacing: 8) {
                        Circle().fill(slice.category.color).frame(width: 8, height: 8)
                        Text("\(slice.category.label) (\(Int((slice.share * 100).rounded()))%)")
                            .font(.captionSmall)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text(CurrencyFormatter.string(from: slice.total))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
        }
    }

    private var topCategories: some View {
        let totals = digest.categoryTotals
        let maximum = max(totals.first?.total ?? 1, 1)

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "가장 많이 쓴 카테고리")

            VStack(spacing: 16) {
                ForEach(totals.prefix(3), id: \.category) { entry in
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: entry.category.symbolName)
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(width: 20)
                            Text(entry.category.label)
                                .font(.rowTitle)
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(CurrencyFormatter.string(from: entry.total))
                                .font(.rowAmount)
                                .foregroundStyle(Palette.textPrimary)
                        }
                        ProgressBar(
                            ratio: Double(entry.total) / Double(maximum),
                            color: entry.category.color
                        )
                        .padding(.leading, 30)
                    }
                }
            }
        }
    }
}

/// A donut drawn from the slice shares. Hand-drawn rather than using Swift Charts so the ring
/// thickness and the gap-free layout match the design exactly.
private struct DonutChart: View {
    let slices: [(share: Double, color: Color)]
    var thickness: CGFloat = 28

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
