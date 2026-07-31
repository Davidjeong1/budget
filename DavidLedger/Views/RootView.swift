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

    /// SF Symbols standing in for the design's icon set, which is not bundled.
    var symbolName: String {
        switch self {
        case .home: "house"
        case .list: "list.bullet"
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

private struct TabBar: View {
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 18, weight: selection == tab ? .semibold : .regular))
                            .frame(width: 20, height: 20)
                        Text(tab.label)
                            .font(selection == tab ? .system(size: 11, weight: .semibold) : .tabLabel)
                    }
                    .foregroundStyle(selection == tab ? Palette.accent : Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .frame(height: 72)
        .padding(.horizontal, 16)
        .background(Palette.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)
        }
    }
}
