import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import LedgerParser

/// Receives text shared from Messages (or anywhere else) and files it as a payment.
///
/// This is the manual counterpart to the Shortcuts automation, and the only route available for
/// KakaoTalk approval notifications, which iOS never exposes to other apps.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await handleSharedItem() }
    }

    private func handleSharedItem() async {
        guard let text = await loadSharedText() else {
            present(state: .failure("공유된 텍스트를 읽지 못했습니다"))
            return
        }

        // UIViewController is @MainActor, so this whole method already runs on the main actor and
        // can touch mainContext directly.
        do {
            let transaction = try LedgerStore.record(
                messageText: text,
                source: .shareSheet,
                in: LedgerStore.shared.mainContext
            )
            let amount = CurrencyFormatter.string(from: abs(transaction.amount))
            present(state: .success("\(transaction.merchant)\n\(amount)"))
        } catch LedgerStoreError.notAPaymentMessage {
            present(state: .failure("결제 문자로 인식하지 못했습니다"))
        } catch LedgerStoreError.duplicate {
            present(state: .failure("이미 기록된 결제입니다"))
        } catch {
            present(state: .failure("기록에 실패했습니다"))
        }
    }

    private func loadSharedText() async -> String? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else { return nil }

        let plainText = UTType.plainText.identifier
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(plainText) {
            let loaded = try? await provider.loadItem(forTypeIdentifier: plainText)
            if let text = loaded as? String { return text }
            if let url = loaded as? URL, let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        // Messages sometimes hands over the body as the item's attributed content instead.
        return item.attributedContentText?.string
    }

    private func present(state: ShareResultView.State) {
        let view = ShareResultView(state: state) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: view)
        addChild(host)
        host.view.frame = self.view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct ShareResultView: View {
    enum State {
        case success(String)
        case failure(String)
    }

    let state: State
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(isSuccess ? Color.green : Color.orange)

            Text(isSuccess ? "가계부에 기록했습니다" : "기록하지 못했습니다")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("완료", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var isSuccess: Bool {
        if case .success = state { return true }
        return false
    }

    private var message: String {
        switch state {
        case .success(let text), .failure(let text): text
        }
    }
}
