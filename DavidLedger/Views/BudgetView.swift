import SwiftUI
import SwiftData
import LedgerCore

struct BudgetView: View {
    @Binding var month: MonthRange

    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]

    @State private var editingCategory: Category?
    @State private var isEditingTotal = false

    private var digest: MonthlyDigest {
        MonthlyDigest(month: month, allTransactions: allTransactions)
    }

    private var budget: Budget? {
        budgets.first { $0.monthStart == month.start }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "예산 설정") {
                HeaderIconButton(systemName: "plus") { editingCategory = nextUnbudgetedCategory() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    monthStepper
                    totalCard
                    categoryBudgets
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isEditingTotal) {
            AmountEntrySheet(
                title: "총 목표 예산",
                initialAmount: budget?.totalTarget ?? 0
            ) { amount in
                setTotalTarget(amount)
            }
        }
        .sheet(item: $editingCategory) { category in
            AmountEntrySheet(
                title: "\(category.label) 예산",
                initialAmount: budget?.target(for: category) ?? 0
            ) { amount in
                setCategoryTarget(amount, for: category)
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

    private var totalCard: some View {
        Button { isEditingTotal = true } label: {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("총 목표 예산")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        if let target = budget?.totalTarget, target > 0 {
                            Text("\(digest.budgetPercent(target: target))% 사용")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                        }
                    }

                    Text(CurrencyFormatter.string(from: budget?.totalTarget ?? 0))
                        .font(.cardAmount)
                        .foregroundStyle(Palette.textPrimary)

                    if let target = budget?.totalTarget, target > 0 {
                        ProgressBar(
                            ratio: digest.budgetUsage(target: target),
                            color: Palette.accent
                        )
                    } else {
                        Text("탭해서 이 달의 목표 예산을 설정하세요")
                            .font(.captionSmall)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var categoryBudgets: some View {
        let budgeted = budget?.budgetedCategories ?? []

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "카테고리별 예산")

            if budgeted.isEmpty {
                EmptyStateView(
                    title: "카테고리 예산이 없습니다",
                    message: "오른쪽 위 + 를 눌러 카테고리별 목표를 추가하세요."
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(budgeted, id: \.self) { category in
                        categoryRow(category)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        let target = budget?.target(for: category) ?? 0
        let spent = digest.total(for: category)
        let ratio = target > 0 ? Double(spent) / Double(target) : 0
        let percent = Int((ratio * 100).rounded())
        // Past 90% the figure turns red, matching how the design flags 82% and 96% differently.
        let isNearLimit = percent >= 90

        return Button { editingCategory = category } label: {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: category.symbolName)
                            .font(.system(size: 14))
                            .foregroundStyle(category.color)
                            .frame(width: 20)
                        Text(category.label)
                            .font(.rowTitle)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(percent)%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isNearLimit ? Palette.expense : Palette.textSecondary)
                            if isNearLimit {
                                Circle().fill(Palette.expense).frame(width: 5, height: 5)
                            }
                        }
                    }

                    ProgressBar(ratio: ratio, color: category.color)

                    HStack {
                        Text("지출 \(CurrencyFormatter.string(from: spent))")
                        Spacer()
                        Text("목표 \(CurrencyFormatter.string(from: target))")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func nextUnbudgetedCategory() -> Category {
        let budgeted = Set(budget?.budgetedCategories ?? [])
        return Category.expenseCases.first { !budgeted.contains($0) } ?? .etc
    }

    /// Creates the month's budget row on first write, so reading the screen never inserts one.
    private func mutableBudget() -> Budget {
        if let budget { return budget }
        let created = Budget(monthStart: month.start, totalTarget: 0)
        context.insert(created)
        return created
    }

    private func setTotalTarget(_ amount: Int) {
        mutableBudget().totalTarget = amount
    }

    private func setCategoryTarget(_ amount: Int, for category: Category) {
        mutableBudget().setTarget(amount, for: category)
    }
}

/// A small sheet for entering a won amount, shared by the total and per-category budget rows.
private struct AmountEntrySheet: View {
    let title: String
    let initialAmount: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""

    private var amount: Int { Int(digits) ?? 0 }

    var body: some View {
        NavigationStack {
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
            .padding(.horizontal, Metrics.screenPadding)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(amount)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if initialAmount > 0 { digits = String(initialAmount) }
            }
        }
        .presentationDetents([.height(300)])
    }
}
