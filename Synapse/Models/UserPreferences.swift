import Foundation
import SwiftData

enum OnboardingGoal: String, CaseIterable, Codable, Identifiable {
    case organizeDay
    case rememberTasks
    case buildHabits
    case prioritize
    case reduceStress
    case somethingElse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .organizeDay:
            return "Organize my day"
        case .rememberTasks:
            return "Remember my tasks"
        case .buildHabits:
            return "Build habits"
        case .prioritize:
            return "Prioritize what matters"
        case .reduceStress:
            return "Reduce stress"
        case .somethingElse:
            return "Something else"
        }
    }
}

enum HabitTimeBlock: String, CaseIterable, Codable, Identifiable {
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        }
    }

    var partOfDay: TaskPartOfDay {
        switch self {
        case .morning:
            return .morning
        case .afternoon:
            return .afternoon
        case .evening:
            return .evening
        }
    }
}

enum CalendarProviderChoice: String, CaseIterable, Codable, Identifiable {
    case apple
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }
}

enum CalendarIntegrationState: String, Codable, CaseIterable {
    case notConfigured
    case skipped
    case connected
}

enum CalendarIntegrationMode: String, Codable, CaseIterable {
    case readOnly
}

@Model
final class UserPreferences {
    var id: UUID = UUID()
    var goalsRaw: String = ""
    var notificationsEnabled: Bool = false
    var enabledTimeBlocksRaw: String = ""
    var calendarIntegrationStateRaw: String = CalendarIntegrationState.notConfigured.rawValue
    var connectedProvidersRaw: String = ""
    var selectedCalendarIDsRaw: String = ""
    var calendarIntegrationModeRaw: String = CalendarIntegrationMode.readOnly.rawValue
    var hasCompletedOnboarding: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.goalsRaw = ""
        self.notificationsEnabled = false
        self.enabledTimeBlocksRaw = ""
        self.calendarIntegrationStateRaw = CalendarIntegrationState.notConfigured.rawValue
        self.connectedProvidersRaw = ""
        self.selectedCalendarIDsRaw = ""
        self.calendarIntegrationModeRaw = CalendarIntegrationMode.readOnly.rawValue
        self.hasCompletedOnboarding = false
        self.createdAt = .now
        self.updatedAt = .now
    }

    var goals: Set<OnboardingGoal> {
        get {
            decodeSet(goalsRaw, as: OnboardingGoal.self)
        }
        set {
            goalsRaw = encodeSet(newValue)
        }
    }

    var enabledTimeBlocks: Set<HabitTimeBlock> {
        get {
            decodeSet(enabledTimeBlocksRaw, as: HabitTimeBlock.self)
        }
        set {
            enabledTimeBlocksRaw = encodeSet(newValue)
        }
    }

    var connectedProviders: Set<CalendarProviderChoice> {
        get {
            decodeSet(connectedProvidersRaw, as: CalendarProviderChoice.self)
        }
        set {
            connectedProvidersRaw = encodeSet(newValue)
        }
    }

    var selectedCalendarIDs: Set<String> {
        get {
            decodeStringSet(selectedCalendarIDsRaw)
        }
        set {
            selectedCalendarIDsRaw = encodeStringSet(newValue)
        }
    }

    var calendarIntegrationState: CalendarIntegrationState {
        get {
            CalendarIntegrationState(rawValue: calendarIntegrationStateRaw) ?? .notConfigured
        }
        set {
            calendarIntegrationStateRaw = newValue.rawValue
        }
    }

    var calendarIntegrationMode: CalendarIntegrationMode {
        get {
            CalendarIntegrationMode(rawValue: calendarIntegrationModeRaw) ?? .readOnly
        }
        set {
            calendarIntegrationModeRaw = newValue.rawValue
        }
    }

    func touch() {
        updatedAt = .now
    }

    private func decodeSet<T: RawRepresentable>(_ raw: String, as type: T.Type) -> Set<T> where T.RawValue == String {
        Set(
            raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap(T.init(rawValue:))
        )
    }

    private func encodeSet<T: RawRepresentable>(_ input: Set<T>) -> String where T.RawValue == String {
        input
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }

    private func decodeStringSet(_ raw: String) -> Set<String> {
        Set(
            raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private func encodeStringSet(_ input: Set<String>) -> String {
        input
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: ",")
    }
}
