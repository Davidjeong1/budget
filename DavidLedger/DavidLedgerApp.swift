import SwiftUI
import SwiftData

@main
struct DavidLedgerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(sharedContainer)
    }

    /// Built once and shared with the extensions through the App Group. If this fails the app has
    /// no store at all, so there is nothing sensible to fall back to.
    private let sharedContainer: ModelContainer = {
        do {
            return try LedgerStore.makeSharedContainer()
        } catch {
            fatalError("가계부 저장소를 열지 못했습니다: \(error)")
        }
    }()
}
