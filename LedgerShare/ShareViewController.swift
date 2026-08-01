import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// The share extension's entry point, named by `NSExtensionPrincipalClass` in Info.plist.
///
/// Its only job is to get the shared text out of the extension context and hand it to SwiftUI —
/// everything the user sees is `ShareImportView`, and everything it understands about the message
/// is `PaymentMessageParser`, which the app uses too.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { [weak self] in
            guard let self else { return }
            let text = await sharedText() ?? ""
            installImportView(text: text)
        }
    }

    /// Built here rather than inside the `Task`, so the escaping callbacks are not closures nested
    /// in another closure — the compiler flags a nested `[weak self]` as disagreeing with the
    /// enclosing capture. They stay weak: the view controller owns the hosting controller, which
    /// owns the view, which holds these.
    private func installImportView(text: String) {
        install(
            ShareImportView(
                text: text,
                onFinish: { [weak self] in self?.finish() },
                onCancel: { [weak self] in self?.cancel() }
            )
        )
    }

    private func install(_ root: some View) {
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    /// Senders disagree about how they hand text over, so every shape is tried before giving up.
    /// An empty result is not an error: the view still opens and the user can paste or type.
    private func sharedText() async -> String? {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []

        for item in items {
            for provider in item.attachments ?? [] {
                let identifier = UTType.plainText.identifier
                guard provider.hasItemConformingToTypeIdentifier(identifier) else { continue }

                let loaded = try? await provider.loadItem(forTypeIdentifier: identifier)
                if let text = loaded as? String { return text }
                if let text = loaded as? NSString { return text as String }
                if let data = loaded as? Data { return String(data: data, encoding: .utf8) }
            }
        }

        // Some senders put the text on the item itself rather than in an attachment.
        return items.compactMap { $0.attributedContentText?.string }.first
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(domain: "com.davidjeong.ledger.share", code: NSUserCancelledError)
        )
    }
}
