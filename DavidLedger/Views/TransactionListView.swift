import SwiftUI
import SwiftData
import WidgetKit
import LedgerCore

struct TransactionListView: View {
    @Binding var month: MonthRange

    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var customCategories: [CustomCategory]

    @State private var filter: ListFilter = .all
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var editing: Transaction?
    @State private var pendingDelete: Transaction?

    /// The pills across the top: the two modes plus the categories actually used this month, so the
    /// row does not fill with categories the user never touches.
    private enum ListFilter: Hashable {
        case all
        case expense
        case income
        /// The stored key, so a pill keeps working across a rename of the user's own category.
        case category(String)
    }

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private func label(for filter: ListFilter) -> String {
        switch filter {
        case .all: "전체"
        case .expense: "지출"
        case .income: "수입"
        case .category(let raw): catalog.category(forRaw: raw).label
        }
    }

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    private var availableFilters: [ListFilter] {
        let used = digest.transactions
            .map(\.categoryRaw)
            .reduce(into: [String]()) { result, raw in
                if !result.contains(raw) { result.append(raw) }
            }
            .sorted { catalog.orderIndex(ofRaw: $0) < catalog.orderIndex(ofRaw: $1) }
        return [.all, .expense, .income] + used.map { ListFilter.category($0) }
    }

    private var sections: [(day: Date, rows: [Transaction])] {
        digest.daySections.compactMap { section in
            let rows = section.rows.filter(matches)
            guard !rows.isEmpty else { return nil }
            return (section.day, rows)
        }
    }

    private func performPendingDelete() {
        guard let pendingDelete else { return }
        self.pendingDelete = nil
        withAnimation { context.delete(pendingDelete) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func matches(_ transaction: Transaction) -> Bool {
        let passesFilter: Bool
        switch filter {
        case .all: passesFilter = true
        case .expense: passesFilter = transaction.isExpense
        case .income: passesFilter = !transaction.isExpense
        case .category(let raw): passesFilter = transaction.categoryRaw == raw
        }
        guard passesFilter else { return false }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return transaction.merchant.localizedCaseInsensitiveContains(query)
            || transaction.memo.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isSearching { searchField }

            filterPills

            if sections.isEmpty {
                EmptyStateView(
                    title: "표시할 내역이 없습니다",
                    message: "다른 달을 보거나 필터를 바꿔 보세요."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(sections, id: \.day) { section in
                            dayGroup(section)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, 12)
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
            // A category pill for a category this month has no rows in would otherwise stay
            // selected and silently hide everything with no visible way back.
            if !availableFilters.contains(filter) { filter = .all }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("소비 내역")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            // The month control the other screens share; the design draws none here, but the list
            // is scoped to one month like everything else.
            HStack(spacing: 10) {
                Button { month = month.previous } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                Text(month.monthLabel)
                    .font(.system(size: 13, weight: .semibold))
                Button { month = month.next } label: {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Palette.textSecondary)

            Button {
                isSearching.toggle()
                if !isSearching { searchText = "" }
            } label: {
                Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }

    private var searchField: some View {
        TextField("사용처나 메모로 검색", text: $searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border, lineWidth: 1))
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, 8)
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters, id: \.self) { option in
                    let isSelected = option == filter
                    Button {
                        filter = option
                    } label: {
                        Text(label(for: option))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Palette.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSelected ? Palette.accent : Palette.surface)
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
        .padding(.vertical, 8)
    }

    /// A day's rows, banded together in one card with hairlines between them.
    private func dayGroup(_ section: (day: Date, rows: [Transaction])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.day.dayHeader())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, transaction in
                    Button { editing = transaction } label: {
                        itemRow(transaction)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("삭제", role: .destructive) {
                            withAnimation { context.delete(transaction) }
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }

                    if index < section.rows.count - 1 {
                        Rectangle().fill(Palette.border).frame(height: 1)
                    }
                }
            }
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
    }

    private func itemRow(_ transaction: Transaction) -> some View {
        let category = catalog.category(forRaw: transaction.categoryRaw)
        // Tinted by direction rather than by category, which is what the design shows: the accent
        // for money out, green for money in.
        let tint = transaction.isExpense ? Palette.accent : Palette.income

        return HStack(spacing: 12) {
            Image(systemName: category.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text("\(category.label) • \(transaction.occurredAt.timeLabel)")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(CurrencyFormatter.signedString(from: transaction.signedAmount))
                .font(.rowAmount)
                .foregroundStyle(transaction.isExpense ? Palette.textPrimary : Palette.income)
                .lineLimit(1)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
