import SwiftUI
import SwiftData
import LedgerParser

struct AddEditView: View {
    /// nil when adding a new entry.
    let transaction: Transaction?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var memo = ""
    @State private var category: Category = .etc
    @State private var isExpense = true
    @State private var occurredAt = Date.now
    @State private var didLoad = false
    /// Copied out of the model on appear. Reading it off `transaction` during body would crash if
    /// the body re-evaluates between deleting the model and the sheet tearing down.
    @State private var rawMessage: String?

    private var amount: Int? {
        let digits = amountText.filter(\.isNumber)
        guard let magnitude = Int(digits) else { return nil }
        // Cancellations are stored as negative amounts, so editing one must not flip its sign.
        return amountText.trimmingCharacters(in: .whitespaces).hasPrefix("-") ? -magnitude : magnitude
    }

    private var canSave: Bool {
        guard let amount, amount != 0 else { return false }
        return !merchant.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("종류", selection: $isExpense) {
                        Text("지출").tag(true)
                        Text("수입").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        TextField("금액", text: $amountText)
                            .keyboardType(.numbersAndPunctuation)
                        Text("원").foregroundStyle(.secondary)
                    }
                    TextField("사용처", text: $merchant)
                    DatePicker("일시", selection: $occurredAt)
                }

                Section("분류") {
                    Picker("분류", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("메모") {
                    TextField("메모", text: $memo, axis: .vertical)
                }

                if let rawMessage {
                    Section("자동 인식된 원본 메시지") {
                        Text(rawMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if transaction != nil {
                    Section {
                        Button("삭제", role: .destructive, action: deleteAndDismiss)
                    }
                }
            }
            .navigationTitle(transaction == nil ? "내역 추가" : "내역 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private func loadIfNeeded() {
        guard !didLoad, let transaction else { didLoad = true; return }
        amountText = String(transaction.amount)
        merchant = transaction.merchant
        memo = transaction.memo
        category = transaction.category
        isExpense = transaction.isExpense
        occurredAt = transaction.occurredAt
        rawMessage = transaction.rawMessage
        didLoad = true
    }

    private func save() {
        guard let amount else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        let trimmedMemo = memo.trimmingCharacters(in: .whitespaces)

        if let transaction {
            transaction.amount = amount
            transaction.isExpense = isExpense
            transaction.merchant = trimmedMerchant
            transaction.category = category
            transaction.memo = trimmedMemo
            transaction.occurredAt = occurredAt
        } else {
            context.insert(
                Transaction(
                    amount: amount,
                    isExpense: isExpense,
                    merchant: trimmedMerchant,
                    category: category,
                    memo: trimmedMemo,
                    occurredAt: occurredAt
                )
            )
        }
        dismiss()
    }

    /// Dismisses before deleting, so no further body evaluation can touch the deleted model.
    private func deleteAndDismiss() {
        guard let transaction else { return dismiss() }
        dismiss()
        DispatchQueue.main.async { context.delete(transaction) }
    }
}
