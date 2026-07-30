import SwiftUI
import SwiftData
import LedgerParser

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var testText = ""
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("iOS는 앱이 문자나 다른 앱의 알림을 직접 읽는 것을 허용하지 않습니다. "
                         + "대신 **단축어 자동화**를 한 번 만들어두면, 문자가 올 때마다 그 내용이 "
                         + "이 앱으로 전달되어 자동으로 기록됩니다.")
                    .font(.footnote)
                } header: {
                    Text("자동 기록은 이렇게 동작합니다")
                }

                Section("단축어 자동화 만들기") {
                    ForEach(Array(automationSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 18, height: 18)
                                .background(.tint.opacity(0.15), in: Circle())
                            Text(step).font(.footnote)
                        }
                    }

                    Link(destination: URL(string: "shortcuts://")!) {
                        Label("단축어 앱 열기", systemImage: "arrow.up.forward.app")
                    }
                }

                Section {
                    Text("카카오톡으로 오는 승인 알림톡은 iOS에서 어떤 앱도 읽을 수 없습니다. "
                         + "카카오톡 결제 알림은 알림을 길게 눌러 공유하거나 직접 입력해 주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("카카오톡 알림")
                }

                Section {
                    Text("문자를 길게 눌러 **공유 → 다비드 가계부**를 선택하면 그 자리에서 기록됩니다.")
                        .font(.footnote)
                } header: {
                    Text("공유 시트로 기록하기")
                }

                testSection

                Section {
                    Text("읽어들인 메시지는 기기 안에서만 분석되고 저장됩니다. 외부로 전송되지 않습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("개인정보 처리")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    /// Lets the user check their own card company's wording before trusting the automation with
    /// it, rather than finding out weeks later that nothing was recorded.
    private var testSection: some View {
        Section {
            TextField("카드 승인 문자를 붙여넣어 보세요", text: $testText, axis: .vertical)
                .lineLimit(3...6)
                .font(.footnote)

            Button("인식 결과 확인") { runTest() }
                .disabled(testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let testResult {
                Text(testResult).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("인식 테스트")
        } footer: {
            Text("여기서는 가계부에 저장하지 않고 인식 결과만 보여줍니다.")
        }
    }

    private func runTest() {
        guard let payment = PaymentMessageParser.parse(testText, source: .manual) else {
            testResult = "결제 문자로 인식하지 못했습니다."
            return
        }
        var lines = [
            "금액: \(CurrencyFormatter.string(from: payment.amount))",
            "사용처: \(payment.merchant ?? "인식 실패")",
            "분류: \(MerchantCategoryClassifier.classify(payment.merchant).label)",
        ]
        if let issuer = payment.issuer { lines.append("카드사: \(issuer)") }
        if let last4 = payment.cardLast4 { lines.append("카드번호: \(last4)") }
        if let months = payment.installmentMonths { lines.append("할부: \(months)개월") }
        if payment.isCancellation { lines.append("승인 취소 건") }
        testResult = lines.joined(separator: "\n")
    }

    private let automationSteps = [
        "단축어 앱에서 [자동화] 탭을 엽니다.",
        "[새로운 자동화] → [메시지]를 선택합니다.",
        "[메시지에 다음이 포함] 에 '승인' 을 넣고, 보낸 사람은 비워 둡니다.",
        "[즉시 실행] 을 켜고 [실행 시 알림] 은 끕니다.",
        "동작으로 [결제 문자 가계부에 기록] 을 추가합니다.",
        "메시지 내용 항목에 [메시지 내용] 변수를 넣고 저장합니다.",
    ]
}
