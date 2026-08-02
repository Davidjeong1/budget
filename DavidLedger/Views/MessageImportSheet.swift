import SwiftUI
import LedgerCore

/// Fills the add screen from a card-approval text message the user pastes in.
///
/// iOS cannot read these messages on its own, so the app takes one that is handed to it. The parse
/// is shown before anything is applied: the carriers' formats are undocumented and inconsistent, so
/// a wrong read has to be visible rather than silently written into the ledger.
struct MessageImportSheet: View {
    let onApply: (PaymentMessage, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    /// The message field takes several lines, so its return key has to stay a newline — which
    /// leaves the 완료 accessory as the only way to put the keyboard away.
    @FocusState private var isMessageFocused: Bool

    private var parsed: PaymentMessage? { PaymentMessageParser.parse(text) }

    private var occurredAt: Date? { parsed?.occurredAt() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pasteRow
                    messageField
                    result
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .navigationTitle("문자로 채우기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { isMessageFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("적용") {
                        if let parsed {
                            onApply(parsed, occurredAt)
                        }
                        dismiss()
                    }
                    .disabled(parsed == nil)
                }
            }
        }
    }

    private var pasteRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A PasteButton rather than reading the pasteboard directly: the system grants this one
            // read on the tap, so the user is never asked to approve a paste they did not ask for.
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first { text = pasted }
            }
            .labelStyle(.titleAndIcon)
            .tint(Palette.accent)

            Text("카드 승인 문자를 복사한 뒤 붙여넣기를 누르세요. 직접 입력해도 됩니다.")
                .font(.captionSmall)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var messageField: some View {
        TextField("[Web발신]\n신한카드(1234)승인\n5,500원\n07/31 14:23\n스타벅스", text: $text, axis: .vertical)
            .focused($isMessageFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .lineLimit(4...10)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardSurface(cornerRadius: 12)
    }

    @ViewBuilder
    private var result: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else if let parsed {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "읽은 내용")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        resultRow("금액", CurrencyFormatter.string(from: parsed.amount))
                        resultRow("사용처", parsed.merchant ?? "읽지 못함")
                        resultRow("날짜", occurredAt.map { $0.importLabel } ?? "읽지 못함")
                    }
                }

                if parsed.isCancellation {
                    Text("취소 문자로 보입니다. 이대로 저장하면 지출로 기록되니, 금액과 구분을 확인하세요.")
                        .font(.captionSmall)
                        .foregroundStyle(Palette.expense)
                }

                if parsed.merchant == nil || occurredAt == nil {
                    Text("읽지 못한 항목은 비워 둡니다. 적용한 뒤 직접 채우면 됩니다.")
                        .font(.captionSmall)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        } else {
            EmptyStateView(
                title: "금액을 찾지 못했습니다",
                message: "승인 문자 전체를 붙여넣었는지 확인해 주세요. 금액이 없으면 기록할 수 없습니다."
            )
        }
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.captionRegular)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
        }
    }
}

private extension Date {
    /// "7월 31일 14:23" — enough to check the parse against the message on screen.
    var importLabel: String {
        formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day().hour().minute())
    }
}
