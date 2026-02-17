import Foundation
import SwiftData

enum TaskState: String, Codable, CaseIterable {
    case inbox
    case today
    case completed
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var stateRaw: String
    var createdAt: Date
    var completedAt: Date?
    var focusSeconds: Int

    init(title: String, state: TaskState = .inbox, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.stateRaw = state.rawValue
        self.createdAt = createdAt
        self.completedAt = nil
        self.focusSeconds = 0
    }

    var state: TaskState {
        get { TaskState(rawValue: stateRaw) ?? .inbox }
        set { stateRaw = newValue.rawValue }
    }
}

@Model
final class FocusSession {
    var id: UUID
    var taskId: UUID
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int

    init(taskId: UUID, startedAt: Date = .now) {
        self.id = UUID()
        self.taskId = taskId
        self.startedAt = startedAt
        self.endedAt = nil
        self.durationSeconds = 0
    }
}
