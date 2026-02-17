import SwiftUI
import SwiftData

@main
struct SynapseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TaskItem.self, FocusSession.self])
    }
}