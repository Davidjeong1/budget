import SwiftUI
import SwiftData
import LedgerParser

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]

    @State private var month = MonthRange(containing: .now)
    @State private var editing: Transaction?
    @State private var isAdding = false
    @State private var showsSettings = false

    private var transactions: [Transaction] {
        allTransactions.filter { month.contains($0.occurredAt) }
    }

    private var expenseTotal: Int {
        transactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    private var incomeTotal: Int {
        transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    /// Nets cancellations into their category so the bars add up to `expenseTotal`. A category
    /// that ends up at or below zero is dropped rather than drawn as an empty bar.
    private var categoryTotals: [(category: Category, total: Int)] {
        Dictionary(grouping: transactions.filter(\.isExpense), by: \.category)
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthSummaryCard(
                        month: $month,
                        expenseTotal: expenseTotal,
                        incomeTotal: incomeTotal,
                        categoryTotals: categoryTotals
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if transactions.isEmpty {
                    Section { EmptyLedgerMessage() }
                } else {
                    Section {
                        ForEach(transactions) { transaction in
                            Button { editing = transaction } label: {
                                TransactionRow(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("다비드 가계부")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showsSettings = true } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: {
                        Label("직접 입력", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) { AddEditView(transaction: nil) }
            .sheet(item: $editing) { AddEditView(transaction: $0) }
            .sheet(isPresented: $showsSettings) { SettingsView() }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(transactions[index])
        }
    }
}

private struct MonthSummaryCard: View {
    @Binding var month: MonthRange
    let expenseTotal: Int
    let incomeTotal: Int
    let categoryTotals: [(category: Category, total: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { month = month.previous } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(month.title).font(.headline)
                Spacer()
                Button { month = month.next } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyFormatter.string(from: expenseTotal))
                    .font(.largeTitle.bold())
                // Not "이번 달" — the card pages through months.
                Text("지출").font(.subheadline).foregroundStyle(.secondary)
            }

            if incomeTotal > 0 {
                Text("수입 \(CurrencyFormatter.string(from: incomeTotal))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !categoryTotals.isEmpty {
                CategoryBreakdown(entries: categoryTotals)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct CategoryBreakdown: View {
    let entries: [(category: Category, total: Int)]

    var body: some View {
        let maximum = max(entries.map(\.total).max() ?? 1, 1)

        VStack(spacing: 6) {
            ForEach(entries.prefix(5), id: \.category) { entry in
                HStack(spacing: 8) {
                    Text(entry.category.label)
                        .font(.caption)
                        .frame(width: 68, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * ratio(entry.total, of: maximum))
                        }
                    }
                    .frame(height: 8)

                    Text(CurrencyFormatter.string(from: entry.total))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func ratio(_ value: Int, of maximum: Int) -> Double {
        min(max(Double(value) / Double(maximum), 0), 1)
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.merchant).font(.subheadline.weight(.semibold))
                    if transaction.isAutoCaptured {
                        Text("자동")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.signedString(from: transaction.signedAmount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.signedAmount < 0 ? Color.primary : Color.green)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [
            transaction.category.label,
            "\(transaction.occurredAt.dayLabel) \(transaction.occurredAt.timeLabel)",
        ]
        if let months = transaction.installmentMonths {
            parts.append("\(months)개월 할부")
        }
        return parts.joined(separator: " · ")
    }
}

private struct EmptyLedgerMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("아직 내역이 없습니다").font(.subheadline.weight(.semibold))
            Text("설정에서 단축어 자동화를 만들면 카드 승인 문자가 도착할 때마다 자동으로 기록됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

/// A calendar month, used to scope the ledger list and the totals.
struct MonthRange: Equatable {
    let start: Date
    let end: Date
    private let calendar: Calendar

    init(containing date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        let interval = calendar.dateInterval(of: .month, for: date)
        self.start = interval?.start ?? date
        self.end = interval?.end ?? date
    }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    var title: String {
        start.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).year().month())
    }

    var previous: MonthRange {
        let date = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        return MonthRange(containing: date, calendar: calendar)
    }

    var next: MonthRange {
        let date = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return MonthRange(containing: date, calendar: calendar)
    }

    static func == (lhs: MonthRange, rhs: MonthRange) -> Bool { lhs.start == rhs.start }
}
