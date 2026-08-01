import SwiftUI
import LedgerCore

/// The bar the month-scoped screens carry: title, the shared month control, and one optional
/// action at the trailing edge.
///
/// The month control is not in the redesign, but all six screens look at the same month and
/// without it the ledger is stuck on the current one. Shared from here so the three screens that
/// carry it cannot drift apart.
struct ScreenTitleBar<Trailing: View>: View {
    let title: String
    @Binding var month: MonthRange
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            MonthStepper(month: $month)

            trailing
                .padding(.leading, 12)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }
}

extension ScreenTitleBar where Trailing == EmptyView {
    init(title: String, month: Binding<MonthRange>) {
        self.init(title: title, month: month) { EmptyView() }
    }
}

/// Steps back and forth through the months. Every screen shares one `MonthRange`, so this is the
/// same control wherever it appears.
struct MonthStepper: View {
    @Binding var month: MonthRange

    var body: some View {
        HStack(spacing: 10) {
            Button { month = month.previous } label: {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("이전 달")

            Text(month.monthLabel)
                .font(.system(size: 13, weight: .semibold))

            Button { month = month.next } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("다음 달")
        }
        .foregroundStyle(Palette.textSecondary)
    }
}

/// A tappable icon at the trailing edge of a title bar, sized to the design's 20pt icon box.
struct HeaderIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension View {
    /// The bordered surface every card, row group and field sits on. It was written out in nine
    /// files before it was named, which is what the duplication report was pointing at.
    func cardSurface(
        _ fill: Color = Palette.surface,
        cornerRadius: CGFloat = Metrics.cardRadius
    ) -> some View {
        background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Palette.border, lineWidth: 1)
            )
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String?
    var onTrailingTap: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            if let trailing {
                Button {
                    onTrailingTap?()
                } label: {
                    Text(trailing)
                        .font(.captionRegular)
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
                .disabled(onTrailingTap == nil)
            }
        }
    }
}

/// The bordered light-grey card used for the summary panels.
struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
    }
}

/// A rounded track with a coloured fill, used for budget usage and category share.
struct ProgressBar: View {
    let ratio: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// The round category badge on list rows and category chips.
struct CategoryIcon: View {
    let category: LedgerCategory
    var size: CGFloat = 36
    /// Overrides the category's own colour. Transaction rows tint by direction — the accent for
    /// money out, green for money in — rather than by category, which is what the design shows.
    var tint: Color?

    private var colour: Color { tint ?? category.color }

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(colour)
            .frame(width: size, height: size)
            .background(colour.opacity(0.1))
            .clipShape(Circle())
    }
}

/// A transaction row: badge, merchant, category and day, amount. Carries its own card background,
/// which is how the design draws it on both the dashboard and the 내역 screen.
struct TransactionRow: View {
    let transaction: Transaction
    /// Resolved by the caller, which is the level that holds the catalog.
    let category: LedgerCategory

    private var directionColour: Color {
        transaction.isExpense ? Palette.accent : Palette.income
    }

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            CategoryIcon(category: category, tint: directionColour)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text("\(category.label) • \(transaction.occurredAt.shortDate)")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Money out is no longer red in this design: only income is coloured, so the eye goes
            // to what came in rather than to every line.
            Text(CurrencyFormatter.signedString(from: transaction.signedAmount))
                .font(.rowAmount)
                .foregroundStyle(transaction.isExpense ? Palette.textPrimary : Palette.income)
                .lineLimit(1)
        }
        .padding(14)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.rowRadius))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
            Text(message)
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
