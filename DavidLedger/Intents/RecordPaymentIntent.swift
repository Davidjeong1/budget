import AppIntents
import SwiftData
import LedgerParser

/// The bridge that makes automatic capture possible on iOS.
///
/// iOS gives apps no way to read incoming SMS or other apps' notifications, so the app cannot go
/// and fetch approval messages itself. Instead the user builds a Shortcuts personal automation
/// ("메시지를 받았을 때") once, and that automation hands the message text to this intent. From the
/// app's side this is the only inbound path, which is why all the parsing lives behind LedgerStore.
struct RecordPaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "결제 문자 가계부에 기록"
    static var description = IntentDescription(
        "카드 승인 문자의 내용을 읽어 금액과 사용처를 가계부에 자동으로 기록합니다.",
        categoryName: "가계부"
    )

    /// The automation passes its "메시지 내용" variable here.
    @Parameter(title: "메시지 내용")
    var messageText: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$messageText)을(를) 가계부에 기록")
    }

    /// Running silently is the whole point — an automation that prompts on every payment is worse
    /// than typing the entry by hand.
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            let transaction = try LedgerStore.record(
                messageText: messageText,
                source: .shortcutAutomation,
                in: LedgerStore.shared.mainContext
            )
            let amount = CurrencyFormatter.string(from: abs(transaction.amount))
            return .result(value: "\(transaction.merchant) \(amount) 기록됨")
        } catch LedgerStoreError.notAPaymentMessage {
            // Every incoming message hits this intent, so non-payments are the common case and
            // must not surface as an error the automation reports to the user.
            return .result(value: "결제 문자가 아니어서 기록하지 않았습니다")
        } catch LedgerStoreError.duplicate {
            return .result(value: "이미 기록된 결제입니다")
        } catch {
            // An automation that throws shows the user a failure banner on an ordinary incoming
            // message, so even an unexpected failure returns a value instead.
            return .result(value: "기록에 실패했습니다: \(error.localizedDescription)")
        }
    }
}

struct DavidLedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordPaymentIntent(),
            phrases: [
                "\(.applicationName)에 결제 기록",
                "\(.applicationName)에 결제 내역 추가",
            ],
            shortTitle: "결제 기록",
            systemImageName: "creditcard"
        )
    }
}
