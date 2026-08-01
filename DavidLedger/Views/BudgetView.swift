import SwiftUI
import SwiftData
import WidgetKit
import LedgerCore

struct BudgetView: View {
    @Binding var month: MonthRange

    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var customCategories: [CustomCategory]

    /// One sheet driver rather than two stacked `.sheet` modifiers, which SwiftUI has historically
    /// handled unreliably.
    private enum BudgetSheet: Identifiable {
        case total
        /// Pick which category to budget, then enter the amount without leaving the sheet.
        case chooseCategory
        /// Straight to the amount, for a row that already has a target.
        case category(String)

        var id: String {
            switch self {
            case .total: "total"
            case .chooseCategory: "choose"
            case .category(let raw): raw
            }
        }
    }

    @State private var sheet: BudgetSheet?

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    private var budget: Budget? {
        budgets.first { $0.monthStart == month.start }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    totalCard
                    categoryBudgets
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 12)
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .total:
                NavigationStack {
                    AmountEntryPage(
                        title: "총 목표 예산",
                        initialAmount: budget?.totalTarget ?? 0,
                        onSave: { mutableBudget().totalTarget = $0; reloadWidget() },
                        onClose: { sheet = nil }
                    )
                }
                // .medium rather than a fixed height, which the number pad would cover.
                .presentationDetents([.medium])

            case .chooseCategory:
                NavigationStack {
                    CategoryBudgetPicker(
                        categories: catalog.expenseChoices,
                        targets: budget?.categoryTargets ?? [:]
                    )
                    .navigationDestination(for: String.self) { raw in
                        AmountEntryPage(
                            title: "\(catalog.category(forRaw: raw).label) 예산",
                            initialAmount: budget?.target(forRaw: raw) ?? 0,
                            onSave: { mutableBudget().setTarget($0, forRaw: raw); reloadWidget() },
                            onClose: { sheet = nil },
                            showsCancel: false
                        )
                    }
                }

            case .category(let raw):
                NavigationStack {
                    AmountEntryPage(
                        title: "\(catalog.category(forRaw: raw).label) 예산",
                        initialAmount: budget?.target(forRaw: raw) ?? 0,
                        onSave: { mutableBudget().setTarget($0, forRaw: raw); reloadWidget() },
                        onClose: { sheet = nil }
                    )
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("예산 설정")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            // The month control the other screens share; a budget is per month, so it has to be
            // reachable even though the design draws none.
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

            Button { sheet = .chooseCategory } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .accessibilityLabel("카테고리 예산 추가")
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }

    private var totalCard: some View {
        Button { sheet = .total } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(month.monthLabel) 전체 예산 설정")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)

                Text(CurrencyFormatter.string(from: budget?.totalTarget ?? 0))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let target = budget?.totalTarget, target > 0 {
                    HStack(spacing: 6) {
                        Text("현재 사용률")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                        Text("\(digest.budgetPercent(target: target))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                } else {
                    Text("탭해서 이 달의 목표 예산을 설정하세요")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var categoryBudgets: some View {
        // Sorted here rather than in `Budget`: only the catalog knows where the user's own
        // categories sit relative to the built-in ones.
        let budgeted = (budget?.budgetedRaws ?? [])
            .sorted { catalog.orderIndex(ofRaw: $0) < catalog.orderIndex(ofRaw: $1) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("카테고리별 예산")
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)

            if budgeted.isEmpty {
                EmptyStateView(
                    title: "카테고리 예산이 없습니다",
                    message: "오른쪽 위 + 를 눌러 카테고리별 목표를 추가하세요."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(budgeted, id: \.self) { raw in
                        categoryRow(raw)
                    }
                }
            }
        }
    }

    private func categoryRow(_ raw: String) -> some View {
        let category = catalog.category(forRaw: raw)
        let target = budget?.target(forRaw: raw) ?? 0
        let spent = digest.total(forRaw: raw)
        let ratio = target > 0 ? Double(spent) / Double(target) : 0
        let percent = Int((ratio * 100).rounded())
        // Past 90% the card turns red, matching how the design flags 83% and 96% differently.
        let isNearLimit = percent >= 90
        let tint = isNearLimit ? Palette.expense : Palette.accent

        return Button { sheet = .category(raw) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(category.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isNearLimit ? Palette.expense : Palette.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(CurrencyFormatter.string(from: spent))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("/ \(CurrencyFormatter.string(from: target))")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                ProgressBar(ratio: ratio, color: tint)

                HStack {
                    // The design labels this "남은 예산 여유" but prints the amount used, which is
                    // what the bar shows too. Named for the figure that is actually there.
                    Text(isNearLimit ? "남은 예산 얼마 남지 않음!" : "사용률")
                        .font(.system(size: 11))
                        .foregroundStyle(isNearLimit ? Palette.expense : Palette.textSecondary)
                    Spacer()
                    Text("\(percent)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// The widget shows this month's usage, so a changed target has to reach it.
    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Creates the month's budget row on first write, so reading the screen never inserts one.
    ///
    /// Goes through the store rather than the `@Query` array: that snapshot is stale immediately
    /// after an insert, so a second edit in the same update cycle would insert a duplicate and the
    /// unique constraint would upsert away the value just saved.
    private func mutableBudget() -> Budget {
        if let existing = LedgerStore.budget(for: month, in: context) { return existing }
        let created = Budget(monthStart: month.start, totalTarget: 0)
        context.insert(created)
        return created
    }
}


/// The list the + button opens: every expense category, with the target it already has, so a
/// category budget can be aimed at a chosen category rather than whichever one happened to be next.
private struct CategoryBudgetPicker: View {
    let categories: [LedgerCategory]
    let targets: [String: Int]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(categories) { category in
                    // A push rather than a second sheet: chaining sheet presentations is where
                    // SwiftUI drops the second one.
                    NavigationLink(value: category.raw) {
                        row(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, 16)
        }
        .background(Palette.background)
        .navigationTitle("예산을 정할 카테고리")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ category: LedgerCategory) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category, size: 32)

            Text(category.label)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            if let target = targets[category.raw], target > 0 {
                Text(CurrencyFormatter.string(from: target))
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }
}

/// Entering a won amount. A page rather than a whole sheet, so it works both as the only thing in
/// the sheet and as the second step after picking a category.
private struct AmountEntryPage: View {
    let title: String
    let initialAmount: Int
    let onSave: (Int) -> Void
    /// Closes the sheet outright. `dismiss()` would only pop back to the category list when this
    /// page was pushed onto it.
    let onClose: () -> Void
    /// Off when pushed: a leading 취소 would sit where the back button belongs.
    var showsCancel = true

    @State private var digits = ""

    private var amount: Int { Int(digits) ?? 0 }

    var body: some View {
        VStack(spacing: 20) {
            Text(CurrencyFormatter.string(from: amount))
                .font(.cardAmount)
                .foregroundStyle(amount > 0 ? Palette.textPrimary : Palette.textTertiary)
                .padding(.top, 24)

            TextField("금액", text: $digits)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
                .onChange(of: digits) { _, new in
                    let filtered = String(new.filter(\.isNumber).drop { $0 == "0" }.prefix(12))
                    if filtered != new { digits = filtered }
                }

            Text("0으로 저장하면 목표가 삭제됩니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.screenPadding)
        .background(Palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onClose)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    onSave(amount)
                    onClose()
                }
            }
        }
        .onAppear {
            if initialAmount > 0 { digits = String(initialAmount) }
        }
    }
}
