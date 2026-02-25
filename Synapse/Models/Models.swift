import Foundation
import SwiftData

enum TaskState: String, Codable, CaseIterable {
    case inbox
    case today
    case completed
}

enum TaskPriority: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var displayLabel: String {
        switch self {
        case .high: return "Focus"
        case .medium: return "Support"
        case .low: return "Flexible"
        }
    }

    var sortRank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

enum TaskPartOfDay: String, Codable, CaseIterable {
    case anytime
    case morning
    case afternoon
    case evening

    var displayLabel: String {
        switch self {
        case .anytime: return "Anytime"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

enum TaskRepeatRule: String, Codable, CaseIterable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
    case custom
}

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var stateRaw: String = TaskState.inbox.rawValue
    var priorityRaw: String = TaskPriority.medium.rawValue
    var partOfDayRaw: String = TaskPartOfDay.anytime.rawValue
    var repeatRuleRaw: String = TaskRepeatRule.none.rawValue
    var repeatCustomValue: String?
    var createdAt: Date = Date()
    var assignedDate: Date?
    var repeatAnchorDate: Date?
    var carriedOverFrom: Date?
    var completedAt: Date?
    var focusSeconds: Int = 0

    init(
        title: String,
        state: TaskState = .inbox,
        priority: TaskPriority = .medium,
        partOfDay: TaskPartOfDay = .anytime,
        repeatRule: TaskRepeatRule = .none,
        repeatCustomValue: String? = nil,
        createdAt: Date = .now,
        assignedDate: Date? = nil,
        repeatAnchorDate: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.stateRaw = state.rawValue
        self.priorityRaw = priority.rawValue
        self.partOfDayRaw = partOfDay.rawValue
        self.repeatRuleRaw = repeatRule.rawValue
        self.repeatCustomValue = repeatCustomValue
        self.createdAt = createdAt
        self.assignedDate = assignedDate
        self.repeatAnchorDate = repeatAnchorDate
        self.carriedOverFrom = nil
        self.completedAt = nil
        self.focusSeconds = 0
    }

    var state: TaskState {
        get { TaskState(rawValue: stateRaw) ?? .inbox }
        set { stateRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var partOfDay: TaskPartOfDay {
        get { TaskPartOfDay(rawValue: partOfDayRaw) ?? .anytime }
        set { partOfDayRaw = newValue.rawValue }
    }

    var repeatRule: TaskRepeatRule {
        get { TaskRepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }
}

@Model
final class FocusSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var durationSeconds: Int?
    var elapsedSeconds: Int = 0
    var isPaused: Bool = false
    var taskId: UUID?
    var label: String?
    var createdAt: Date = Date()
    var timeOfDayBucketRaw: String = FocusTimeOfDayBucket.morning.rawValue

    init(
        startDate: Date = .now,
        durationSeconds: Int? = nil,
        elapsedSeconds: Int = 0,
        isPaused: Bool = false,
        taskId: UUID? = nil,
        label: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.durationSeconds = durationSeconds
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.isPaused = isPaused
        self.taskId = taskId
        self.label = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.timeOfDayBucketRaw = FocusSession.bucket(for: startDate).rawValue
    }

    var loggedSeconds: Int {
        max(0, elapsedSeconds)
    }

    var timeOfDayBucket: FocusTimeOfDayBucket {
        get { FocusTimeOfDayBucket(rawValue: timeOfDayBucketRaw) ?? .morning }
        set { timeOfDayBucketRaw = newValue.rawValue }
    }

    func finalize(at endDate: Date = .now) {
        self.endDate = endDate
        self.isPaused = true
        self.timeOfDayBucket = FocusSession.bucket(for: endDate)
    }

    static func bucket(for date: Date, calendar: Calendar = .current) -> FocusTimeOfDayBucket {
        let hour = calendar.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }
}

enum FocusTimeOfDayBucket: String, Codable, CaseIterable {
    case morning
    case afternoon
    case evening
}
