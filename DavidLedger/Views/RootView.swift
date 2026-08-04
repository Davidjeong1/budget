import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case home, list, add, statistics, budget, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "홈"
        case .list: "내역"
        case .add: "추가"
        case .statistics: "통계"
        case .budget: "예산"
        case .settings: "설정"
        }
    }

    /// SF Symbols standing in for the design's icon set, which is not bundled. The 내역 glyph is
    /// the design's clock-with-arrow rather than a plain list.
    var symbolName: String {
        switch self {
        case .home: "house"
        case .list: "clock.arrow.circlepath"
        case .add: "plus.circle"
        case .statistics: "chart.pie"
        case .budget: "wallet.bifold"
        case .settings: "gearshape"
        }
    }
}

/// The six-tab shell. Built by hand rather than with `TabView` so the bar matches the design's
/// 72pt height, hairline top border and 11pt labels.
struct RootView: View {
    @State private var selection: Tab = .home
    @State private var month = MonthRange(containing: .now)

    var body: some View {
        VStack(spacing: 0) {
            if LedgerStore.isEphemeral { StorageWarningBanner() }

            Group {
                switch selection {
                case .home:
                    HomeView(month: $month, onSeeAllTransactions: { selection = .list })
                case .list:
                    TransactionListView(month: $month)
                case .add:
                    AddTransactionView(onSaved: { selection = .home })
                case .statistics:
                    StatisticsView(month: $month)
                case .budget:
                    BudgetView(month: $month)
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $selection)
        }
        .background(Palette.background)
    }
}

/// Shown when the ledger opened against memory instead of the App Group container — usually a
/// signing problem, where the group is missing from the entitlement or is not provisioned.
///
/// The app stays usable on purpose: everything works, it just does not survive a relaunch. Saying
/// so is the whole point, because the failure is otherwise completely silent — rows appear in the
/// list, totals move, and the month is gone the next time the app is opened.
private struct StorageWarningBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 2) {
                Text("기록이 저장되지 않습니다")
                    .font(.system(size: 13, weight: .bold))
                Text("저장소를 열지 못해 임시 메모리로 동작 중입니다. 앱을 닫으면 입력한 내역이 사라집니다.")
                    .font(.captionSmall)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.expense)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.expense.opacity(0.12))
        .accessibilityElement(children: .combine)
    }
}

private struct TabBar: View {
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 16, weight: selection == tab ? .semibold : .regular))
                            .frame(width: 20, height: 20)
                        Text(tab.label)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selection == tab ? Palette.accent : Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        // Padding rather than a fixed height, so the bar keeps its proportions above the home
        // indicator that the system insets for.
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.barBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)
        }
    }
}
