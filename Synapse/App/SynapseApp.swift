import SwiftUI
import SwiftData

@main
struct SynapseApp: App {
    let container: ModelContainer
    @StateObject private var session = AppSession()

    init() {
        let schema = Schema([
            TaskItem.self,
            FocusSession.self,
            Habit.self,
            HabitCompletion.self,
            HabitPausePeriod.self,
            Appointment.self,
            CalendarSyncSettings.self,
            UserPreferences.self
        ])
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
            AppEntryView()
                .environmentObject(session)
                .modelContainer(container)
        }
    }
}
