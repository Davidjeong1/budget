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
    /// The row a long press has offered to delete, held until the user confirms. A category is
    /// deleted by archiving and can be brought back; a transaction cannot, and the app has no undo,
    /// so the one action that destroys a record is the one that asks.
    @State private var deleteCandidate: Transaction?
    /// The search field is the one keyboard on this screen, and the results it filters are behind it.
    @FocusState private var isSearchFocused: Bool

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
        delete(pendingDelete)
    }

    private func delete(_ transaction: Transaction) {
        withAnimation { context.delete(transaction) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// `confirmationDialog` has no `item:` form, so the candidate drives a derived flag. Clearing it
    /// on dismissal matters: a cancelled dialog that left the row behind would refuse to open again
    /// for that same row.
    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )
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
                // Scrolling the results is the natural way to get past the search keyboard.
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { isSearchFocused = false }
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
        // Names the row rather than asking about "이 내역": a long press lands on whichever row the
        // thumb was over, which is not always the one the user meant.
        .confirmationDialog(
            "내역을 삭제할까요?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { transaction in
            // Candidate cleared before the delete, for the same reason the sheet defers its own:
            // the dialog's message reads the row, and it must not still be pointing at a model that
            // no longer exists while it animates away.
            Button("삭제", role: .destructive) {
                deleteCandidate = nil
                delete(transaction)
            }
            Button("취소", role: .cancel) {}
        } message: { transaction in
            Text("\(transaction.merchant) · \(CurrencyFormatter.signedString(from: transaction.signedAmount))\n삭제한 내역은 되돌릴 수 없습니다.")
        }
        .onChange(of: month) { _, _ in
            // A category pill for a category this month has no rows in would otherwise stay
            // selected and silently hide everything with no visible way back.
            if !availableFilters.contains(filter) { filter = .all }
        }
    }

    private var headerBar: some View {
        ScreenTitleBar(title: "소비 내역", month: $month) {
            HeaderIconButton(
                systemName: isSearching ? "xmark" : "magnifyingglass",
                label: isSearching ? "검색 닫기" : "검색"
            ) {
                isSearching.toggle()
                if !isSearching { searchText = "" }
            }
        }
    }

    private var searchField: some View {
        TextField("사용처나 메모로 검색", text: $searchText)
            .focused($isSearchFocused)
            // Results filter as the user types, so the return key's job here is only to get the
            // keyboard out of the way of them.
            .submitLabel(.done)
            .onSubmit { isSearchFocused = false }
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .cardSurface(cornerRadius: 10)
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
                        Button("삭제", role: .destructive) { deleteCandidate = transaction }
                    }

                    if index < section.rows.count - 1 {
                        Rectangle().fill(Palette.border).frame(height: 1)
                    }
                }
            }
            .cardSurface()
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
                .cardSurface(Palette.surfaceRaised, cornerRadius: 10)

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
