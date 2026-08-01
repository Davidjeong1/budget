import SwiftUI
import SwiftData
import LedgerCore

/// What the share sheet shows: the ledger's reading of the message, with one button to keep it.
///
/// Deliberately small, and deliberately not built from the app's shared components — every app file
/// this target compiles is one more thing that has to stay extension-safe. Anything beyond
/// confirming an amount and a merchant belongs in the app, where there is room for it; the point of
/// this screen is not having to open the app at all.
struct ShareImportView: View {
    let text: String
    let onFinish: () -> Void
    let onCancel: () -> Void

    @State private var merchant = ""
    @State private var didLoad = false
    @State private var saveError: String?

    private var parsed: PaymentMessage? { PaymentMessageParser.parse(text) }

    private var occurredAt: Date? { parsed?.occurredAt() }

    /// The same suggestion the add screen makes, from the same classifier. Only built-in categories:
    /// the classifier has no way to know about ones the user invented.
    private var category: Category {
        MerchantCategoryClassifier.classify(merchant)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let parsed {
                    content(parsed)
                } else {
                    unreadable
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.background)
            .navigationTitle("가계부에 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save).disabled(parsed == nil)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var unreadable: some View {
        VStack(spacing: 6) {
            Text("금액을 찾지 못했습니다")
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("카드 승인 문자가 맞는지 확인해 주세요. 앱에서 직접 추가할 수도 있습니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 40)
    }

    private func content(_ message: PaymentMessage) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 6) {
                Text("지출")
                    .font(.captionSmall)
                    .foregroundStyle(Palette.textTertiary)
                Text(CurrencyFormatter.string(from: message.amount))
                    .font(.cardAmount)
                    .foregroundStyle(Palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("사용처").font(.sectionTitle).foregroundStyle(Palette.textPrimary)
                // Editable: the merchant is the field the parse is most likely to get wrong, and it
                // is the one that decides the category.
                TextField("사용처", text: $merchant)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
            }

            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: category.colorHex))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: category.colorHex).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.label)
                        .font(.rowTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(occurredAt.map { $0.shareLabel } ?? "날짜를 읽지 못해 지금 시각으로 저장합니다")
                        .font(.captionSmall)
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
            }

            if message.isCancellation {
                Text("취소 문자로 보입니다. 지출로 저장되니 앱에서 확인해 주세요.")
                    .font(.captionSmall)
                    .foregroundStyle(Palette.expense)
            }

            if let saveError {
                Text(saveError)
                    .font(.captionSmall)
                    .foregroundStyle(Palette.expense)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        merchant = parsed?.merchant ?? ""
    }

    private func save() {
        guard let parsed else { return }

        let name = merchant.trimmingCharacters(in: .whitespaces)
        let transaction = Transaction(
            amount: parsed.amount,
            isExpense: true,
            merchant: name.isEmpty ? "카드 결제" : name,
            categoryRaw: category.rawValue,
            occurredAt: occurredAt ?? .now
        )

        let context = LedgerStore.shared.mainContext
        context.insert(transaction)

        // Saved explicitly rather than left to autosave: the extension is torn down as soon as the
        // request completes, which can come before an automatic save would have run.
        do {
            try context.save()
            onFinish()
        } catch {
            saveError = "저장하지 못했습니다. 앱을 한 번 열어 본 뒤 다시 시도해 주세요."
        }
    }
}

private extension Date {
    /// "7월 31일 14:23"
    var shareLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day().hour().minute())
    }
}
