import SwiftUI
import LedgerCore

/// The header every screen carries: title on the left, one optional action on the right.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            trailing
        }
        .frame(height: 56)
        .padding(.horizontal, Metrics.screenPadding)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// A tappable icon in the header, sized to the design's 20pt icon box.
struct HeaderIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
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
                        .foregroundStyle(Palette.textSecondary)
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
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Palette.border, lineWidth: 1)
            )
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
                Capsule().fill(Palette.border)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// The circular category badge on list rows and category chips.
struct CategoryIcon: View {
    let category: Category
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
    }
}

/// A transaction row with the category badge, used on the 내역 screen.
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            CategoryIcon(category: transaction.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text("\(transaction.category.label) · \(transaction.occurredAt.timeLabel)")
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }

            Spacer()

            Text(CurrencyFormatter.signedString(from: transaction.signedAmount))
                .font(.rowAmount)
                .foregroundStyle(transaction.isExpense ? Palette.expense : Palette.income)
        }
        .padding(.vertical, 4)
    }
}

/// The compact dashboard row: a coloured dot instead of a badge, and a relative day label.
struct CompactTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            Circle()
                .fill(transaction.category.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(transaction.occurredAt.relativeDayAndTime())
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }

            Spacer()

            Text(CurrencyFormatter.signedString(from: transaction.signedAmount))
                .font(.rowAmount)
                .foregroundStyle(transaction.isExpense ? Palette.expense : Palette.income)
        }
        .padding(.vertical, 4)
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
