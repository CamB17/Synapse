import SwiftUI
import SwiftData

@main
struct SynapseApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([TaskItem.self, FocusSession.self, Habit.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
