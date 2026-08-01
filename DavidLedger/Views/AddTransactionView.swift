import SwiftUI
import SwiftData
import WidgetKit
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
    @Query private var customCategories: [CustomCategory]

    @State private var amountDigits = ""
    @State private var merchant = ""
    @State private var memo = ""
    @State private var isExpense = true
    /// Held as the stored key rather than a resolved category, so the selection survives the user
    /// renaming or restyling that category while this sheet is open.
    @State private var categoryRaw = Category.food.rawValue
    @State private var occurredAt = Date.now
    /// Set once the user picks a card, so the merchant-based suggestion stops overriding them.
    @State private var didChooseCategory = false
    @State private var didLoad = false
    @State private var isImportingMessage = false

    private var isEditing: Bool { editing != nil }

    private var amount: Int { Int(amountDigits) ?? 0 }

    private var canSave: Bool {
        amount > 0 && !merchant.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var catalog: CategoryCatalog { CategoryCatalog(customs: customCategories) }

    private var category: LedgerCategory { catalog.category(forRaw: categoryRaw) }

    /// What this mode offers. An archived category is not among them, which is what keeps it out
    /// of new entries.
    private var offeredCategories: [LedgerCategory] {
        isExpense ? catalog.expenseChoices : catalog.incomeChoices
    }

    /// What the grid draws. While editing a row filed under a since-archived category, that card is
    /// appended so the selection stays visible — otherwise saving would silently refile the row.
    private var categories: [LedgerCategory] {
        var options = offeredCategories
        if !options.contains(where: { $0.raw == categoryRaw }) {
            options.append(category)
        }
        return options
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    amountDisplay
                    modeToggle
                    categorySection
                    fieldsSection
                    saveButton
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear(perform: loadIfNeeded)
        .sheet(isPresented: $isImportingMessage) { MessageImportSheet(onApply: apply) }
        .onChange(of: isExpense) { _, expense in
            // The two modes offer different cards, so keep the selection inside the offered set —
            // not `categories`, which always contains the current selection by construction.
            if !offeredCategories.contains(where: { $0.raw == categoryRaw }) {
                categoryRaw = expense ? Category.food.rawValue : Category.salary.rawValue
            }
        }
        .onChange(of: merchant) { _, name in
            guard !didChooseCategory, isExpense else { return }
            // Only ever suggests a built-in: the classifier's keyword table has no way to know
            // about categories the user invented.
            let suggestion = MerchantCategoryClassifier.classify(name)
            if suggestion != .etc { categoryRaw = suggestion.rawValue }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if isEditing {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
            }

            Text(isEditing ? "내역 수정" : "내역 추가")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            if isEditing {
                Button("삭제", role: .destructive, action: deleteAndClose)
                    .font(.system(size: 14, weight: .medium))
            } else {
                // Only when adding: an imported message would overwrite the row being edited.
                Button("문자로 채우기") { isImportingMessage = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }

    private var amountDisplay: some View {
        VStack(spacing: 8) {
            Text("금액 입력")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)

            // A digits-only field keeps the big ₩ figure formatted while the user types. The prompt
            // is empty because the field's own text is invisible and the overlay below already
            // renders a ₩ 0 placeholder — a prompt would show through on top of it.
            TextField("", text: $amountDigits)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(.clear)
                .tint(Palette.accent)
                .overlay(
                    Text(CurrencyFormatter.string(from: amount))
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(amount > 0 ? Palette.accent : Palette.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsHitTesting(false)
                )
                .onChange(of: amountDigits) { _, new in
                    let digits = new.filter(\.isNumber)
                    // Trim leading zeros so "0500" cannot be entered, and cap the magnitude: past
                    // 19 digits `Int(amountDigits)` overflows and returns nil, which reads back as
                    // ₩0 and disables 저장하기 while the field still shows what was typed.
                    let trimmed = String(digits.drop { $0 == "0" }.prefix(12))
                    if trimmed != new { amountDigits = trimmed }
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 24)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "지출", selected: isExpense) { isExpense = true }
            toggleButton(title: "수입", selected: !isExpense) { isExpense = false }
        }
        .padding(4)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.rowRadius).stroke(Palette.border, lineWidth: 1)
        )
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 8)
    }

    private func toggleButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Palette.accent : Palette.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Palette.surfaceRaised : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(selected ? 0.05 : 0), radius: 2, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리 선택")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(categories) { option in
                    categoryCard(option)
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 12)
    }

    private func categoryCard(_ option: LedgerCategory) -> some View {
        let selected = option.raw == categoryRaw

        return Button {
            categoryRaw = option.raw
            didChooseCategory = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                Text(option.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(selected ? Palette.surfaceRaised : Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rowRadius)
                    .stroke(selected ? Palette.accent : Palette.border, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var fieldsSection: some View {
        VStack(spacing: 12) {
            // Not in the design, which shows only 날짜 and 메모 — but the list it feeds prints the
            // merchant on every row, and the category suggestion is driven by it.
            fieldRow(title: "사용처") {
                TextField("예: 스타벅스", text: $merchant)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }

            fieldRow(title: "날짜") {
                DatePicker("날짜", selection: $occurredAt)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            fieldRow(title: "메모") {
                TextField("선택", text: $memo)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 12)
    }

    private func fieldRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 12)
            content()
        }
        .padding(14)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.rowRadius).stroke(Palette.border, lineWidth: 1)
        )
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("저장하기")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Palette.accent : Palette.track)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.rowRadius))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 16)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let editing else { return }
        amountDigits = String(editing.amount)
        merchant = editing.merchant
        memo = editing.memo
        isExpense = editing.isExpense
        categoryRaw = editing.categoryRaw
        occurredAt = editing.occurredAt
        didChooseCategory = true
    }

    /// Fills the form from a parsed card message. Only the fields the message actually carried are
    /// touched, so a partial read leaves the rest for the user rather than blanking it.
    ///
    /// Setting the merchant runs the category suggestion through the same path typing does, which
    /// is why an imported 스타벅스 lands on 카페 without this having to know anything about categories.
    private func apply(_ message: PaymentMessage, occurredAt date: Date?) {
        amountDigits = String(message.amount)
        if let merchant = message.merchant, !merchant.isEmpty {
            self.merchant = merchant
        }
        if let date { occurredAt = date }
        // A card message is always money out, including a cancellation — the sheet flags that case
        // and leaves the correction to the user.
        isExpense = true
    }

    private func save() {
        guard canSave else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        let trimmedMemo = memo.trimmingCharacters(in: .whitespaces)

        if let editing {
            editing.amount = amount
            editing.isExpense = isExpense
            editing.merchant = trimmedMerchant
            editing.categoryRaw = categoryRaw
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
                categoryRaw: categoryRaw,
                memo: trimmedMemo,
                occurredAt: occurredAt
            )
            context.insert(created)
            notifyIfBudgetThresholdCrossed(including: created)
            onSaved()
        }

        // The widget reads the same store but is a separate process; without this it keeps showing
        // the old figure until its next scheduled refresh.
        WidgetCenter.shared.reloadAllTimelines()
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
