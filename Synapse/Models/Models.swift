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
    var taskId: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var durationSeconds: Int = 0

    init(taskId: UUID, startedAt: Date = .now) {
        self.id = UUID()
        self.taskId = taskId
        self.startedAt = startedAt
        self.endedAt = nil
        self.durationSeconds = 0
    }
}
