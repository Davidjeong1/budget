import SwiftUI
import SwiftData
import LedgerCore

struct AddTransactionView: View {
    /// nil when adding; set when the list opens an existing row for editing.
    var editing: Transaction?
    var onSaved: () -> Void
    /// Set by the presenter when editing, so the delete happens after this sheet is gone.
    var onRequestDelete: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Transaction.occurredAt, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]

    @State private var amountDigits = ""
    @State private var merchant = ""
    @State private var memo = ""
    @State private var isExpense = true
    @State private var category: Category = .food
    @State private var occurredAt = Date.now
    /// Set once the user picks a chip, so the merchant-based suggestion stops overriding them.
    @State private var didChooseCategory = false
    @State private var didLoad = false

    private var isEditing: Bool { editing != nil }

    private var amount: Int { Int(amountDigits) ?? 0 }

    private var canSave: Bool {
        amount > 0 && !merchant.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var categories: [Category] {
        isExpense ? Category.expenseCases : Category.incomeCases
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    amountField
                    modeToggle
                    merchantField
                    categoryPicker
                    dateRow
                    memoRow
                    saveButton
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .onAppear(perform: loadIfNeeded)
        .onChange(of: isExpense) { _, expense in
            // The two modes offer different chips, so keep the selection inside the visible set.
            if !categories.contains(category) {
                category = expense ? .food : .salary
            }
        }
        .onChange(of: merchant) { _, name in
            guard !didChooseCategory, isExpense else { return }
            let suggestion = MerchantCategoryClassifier.classify(name)
            if suggestion != .etc { category = suggestion }
        }
    }

    private var header: some View {
        ZStack {
            Text(isEditing ? "내역 수정" : "내역 추가")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)

            HStack {
                if isEditing {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                }
                Spacer()
                if isEditing {
                    Button("삭제", role: .destructive, action: deleteAndClose)
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, Metrics.screenPadding)
    }

    private var amountField: some View {
        VStack(spacing: 6) {
            Text("금액 입력")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)

            // A digits-only field keeps the big ₩ figure formatted while the user types. The
            // prompt is empty because the field's own text is invisible and the overlay below
            // already renders a ₩ 0 placeholder — a prompt would show through on top of it.
            TextField("", text: $amountDigits)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.clear)
                .tint(Palette.accent)
                .overlay(
                    Text(CurrencyFormatter.string(from: amount))
                        .font(.cardAmount)
                        .foregroundStyle(amount > 0 ? Palette.textPrimary : Palette.textTertiary)
                        .allowsHitTesting(false)
                )
                .onChange(of: amountDigits) { _, new in
                    let digits = new.filter(\.isNumber)
                    // Trim leading zeros so "0500" cannot be entered, and cap the magnitude.
                    let trimmed = String(digits.drop { $0 == "0" }.prefix(12))
                    if trimmed != new { amountDigits = trimmed }
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "지출", selected: isExpense) { isExpense = true }
            toggleButton(title: "수입", selected: !isExpense) { isExpense = false }
        }
        .padding(4)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }

    private func toggleButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Palette.textPrimary : Palette.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Palette.background : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var merchantField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("사용처").font(.sectionTitle).foregroundStyle(Palette.textPrimary)
            TextField("예: 스타벅스", text: $merchant)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리").font(.sectionTitle).foregroundStyle(Palette.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(categories, id: \.self) { option in
                    let selected = option == category
                    Button {
                        category = option
                        didChooseCategory = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbolName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                            Text(option.label)
                                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected ? Palette.accent.opacity(0.08) : Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("날짜").font(.sectionTitle).foregroundStyle(Palette.textPrimary)
            DatePicker("날짜", selection: $occurredAt)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
        }
    }

    private var memoRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("메모").font(.sectionTitle).foregroundStyle(Palette.textPrimary)
            TextField("메모를 입력하세요 (선택)", text: $memo, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("저장하기")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Palette.accent : Palette.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.top, 4)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let editing else { return }
        amountDigits = String(editing.amount)
        merchant = editing.merchant
        memo = editing.memo
        isExpense = editing.isExpense
        category = editing.category
        occurredAt = editing.occurredAt
        didChooseCategory = true
    }

    private func save() {
        guard canSave else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        let trimmedMemo = memo.trimmingCharacters(in: .whitespaces)

        if let editing {
            editing.amount = amount
            editing.isExpense = isExpense
            editing.merchant = trimmedMerchant
            editing.category = category
            editing.memo = trimmedMemo
            editing.occurredAt = occurredAt
            notifyIfBudgetThresholdCrossed()
            dismiss()
            onSaved()
        } else {
            let created = Transaction(
                amount: amount,
                isExpense: isExpense,
                merchant: trimmedMerchant,
                category: category,
                memo: trimmedMemo,
                occurredAt: occurredAt
            )
            context.insert(created)
            notifyIfBudgetThresholdCrossed(including: created)
            onSaved()
        }
    }

    /// Checked here rather than on a timer, because a saved expense is the only thing that can
    /// push a month past its budget.
    ///
    /// `including` matters on the insert path: `@Query` does not re-fetch until the next view
    /// update, so the transaction that crosses the threshold is not yet in `allTransactions` and
    /// the alert would otherwise always fire one save late.
    private func notifyIfBudgetThresholdCrossed(including extra: Transaction? = nil) {
        guard AppSettings.shared.budgetAlertEnabled else { return }
        let month = MonthRange(containing: occurredAt)
        guard let budget = budgets.first(where: { $0.monthStart == month.start }),
              budget.totalTarget > 0 else { return }

        let rows = allTransactions + (extra.map { [$0] } ?? [])
        let percent = MonthlyDigest(month: month, allTransactions: rows)
            .budgetPercent(target: budget.totalTarget)
        Task {
            await NotificationScheduler.notifyBudgetThresholdIfNeeded(
                monthStart: month.start,
                percent: percent,
                enabled: true
            )
        }
    }

    /// Deleting is handed to the presenter rather than done here, because the model must not be
    /// deleted while this view is still rendering it through the sheet's dismissal animation.
    private func deleteAndClose() {
        onRequestDelete?()
        dismiss()
    }
}
