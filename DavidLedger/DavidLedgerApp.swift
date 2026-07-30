import SwiftUI
import SwiftData

@main
struct DavidLedgerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        // The same container the App Intent and the share extension use, so a payment recorded by
        // the Shortcuts automation shows up in the open app immediately.
        .modelContainer(LedgerStore.shared)
    }
}
