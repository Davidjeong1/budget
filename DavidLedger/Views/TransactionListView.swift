import SwiftUI
import SwiftData
import LedgerCore

struct TransactionListView: View {
    @Binding var month: MonthRange

    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]

    @State private var filter: ListFilter = .all
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?

    /// The chips across the top: the two modes plus the categories actually used this month, so
    /// the row does not fill with categories the user never touches.
    private enum ListFilter: Hashable {
        case all
        case expense
        case income
        case category(Category)

        var label: String {
            switch self {
            case .all: "전체"
            case .expense: "지출"
            case .income: "수입"
            case .category(let category): category.label
            }
        }
    }

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    private var availableFilters: [ListFilter] {
        let used = digest.transactions
            .map(\.category)
            .reduce(into: [Category]()) { result, category in
                if !result.contains(category) { result.append(category) }
            }
            .sorted { Category.allCases.firstIndex(of: $0)! < Category.allCases.firstIndex(of: $1)! }
        return [.all, .expense, .income] + used.map { ListFilter.category($0) }
    }

    private var sections: [(day: Date, net: Int, rows: [Transaction])] {
        digest.daySections.compactMap { section in
            let rows = section.rows.filter(matches)
            guard !rows.isEmpty else { return nil }
            return (section.day, rows.reduce(0) { $0 + $1.signedAmount }, rows)
        }
    }

    private func performPendingDelete() {
        guard let pendingDelete else { return }
        self.pendingDelete = nil
        withAnimation { context.delete(pendingDelete) }
    }

    private func matches(_ transaction: Transaction) -> Bool {
        let passesFilter: Bool
        switch filter {
        case .all: passesFilter = true
        case .expense: passesFilter = transaction.isExpense
        case .income: passesFilter = !transaction.isExpense
        case .category(let category): passesFilter = transaction.category == category
        }
        guard passesFilter else { return false }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return transaction.merchant.localizedCaseInsensitiveContains(query)
            || transaction.memo.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "소비 내역") {
                HeaderIconButton(systemName: isSearching ? "xmark" : "magnifyingglass") {
                    isSearching.toggle()
                    if !isSearching { searchText = "" }
                }
            }

            if isSearching {
                TextField("사용처나 메모로 검색", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, 12)
            }

            filterChips

            if sections.isEmpty {
                EmptyStateView(
                    title: "표시할 내역이 없습니다",
                    message: "다른 달을 보거나 필터를 바꿔 보세요."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                        ForEach(sections, id: \.day) { section in
                            daySection(section)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        // Deletions are deferred to onDismiss: removing the model while the sheet is still
        // animating out would leave the sheet rendering a deleted object.
        .sheet(item: $editing, onDismiss: performPendingDelete) { transaction in
            AddTransactionView(
                editing: transaction,
                onSaved: { editing = nil },
                onRequestDelete: { pendingDelete = transaction }
            )
        }
        .onChange(of: month) { _, _ in
            // A category chip for a category this month has no rows in would otherwise stay
            // selected and silently hide everything with no visible way back.
            if !availableFilters.contains(filter) { filter = .all }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters, id: \.self) { option in
                    let isSelected = option == filter
                    Button {
                        filter = option
                    } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Palette.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Palette.textPrimary : Palette.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? .clear : Palette.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    private func daySection(_ section: (day: Date, net: Int, rows: [Transaction])) -> some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack {
                Text(section.day.dayHeader())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(CurrencyFormatter.signedString(from: section.net))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(section.net < 0 ? Palette.expense : Palette.income)
            }

            ForEach(section.rows) { transaction in
                Button { editing = transaction } label: {
                    TransactionRow(transaction: transaction)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("삭제", role: .destructive) {
                        withAnimation { context.delete(transaction) }
                    }
                }
            }
        }
    }
}
