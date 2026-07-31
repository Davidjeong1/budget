import SwiftUI
import SwiftData

@main
struct DavidLedgerApp: App {
    @State private var settings = AppSettings.shared
    @State private var isUnlocked = false

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.biometricLockEnabled && !isUnlocked {
                    LockScreen { isUnlocked = true }
                } else {
                    RootView()
                }
            }
            // Turning the lock off while locked must not leave the user stuck behind it.
            .onChange(of: settings.biometricLockEnabled) { _, enabled in
                if !enabled { isUnlocked = true }
            }
        }
        .modelContainer(LedgerStore.shared)
    }
}
