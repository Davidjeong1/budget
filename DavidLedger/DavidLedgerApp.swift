import SwiftUI
import SwiftData

@main
struct DavidLedgerApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
            // Re-lock on background. Without this the lock is a launch-time formality and the
            // ledger stays open for the rest of the process's life.
            .onChange(of: scenePhase) { _, phase in
                if phase == .background && settings.biometricLockEnabled {
                    isUnlocked = false
                }
            }
        }
        .modelContainer(LedgerStore.shared)
    }
}
